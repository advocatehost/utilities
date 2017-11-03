#!/bin/bash
echo "This script should only be run on centos 7 with python 2.7 Continue? y/n"
read CONTINUE

if [ $CONTINUE != "y" ]
    then
        exit
fi

echo "Enter the MySQL DB username:"
read DBUSERNAME
echo "Enter the DB Password:"
read DBPASS
echo "Enter the DB Name:"
read DBNAME
echo "Enter a new DB PW for the root user to be setup. Keep in mind that you'll need to enter this same password later again in a few minutes."
read ROOTPW
echo "Server Public IP address"
read IPADDRESS
echo "Enter a 32 character string of letters and numbers:"
read SECRET_KEY

#yum install epel-release wget
#wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
#sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
#rm -f mysql-community-release-el7-5.noarch.rpm
echo "Installing:"
echo "The EPEL Repo"
echo "Graphite Web"
echo "MySQL Client"
echo "MySQL Server"
echo "MySQL Python"
echo "Python Carbon"
sleep 3
yum install epel-release graphite-web mysql mysql-server MySQL-python python-carbon

echo "Starting the MySQL Deamon now."
sleep 3
systemctl start mysqld

echo "Starting the MySQL Secure Installation Script now."
sleep 3
mysql_secure_installation

echo "Configuring Django and Graphite Web automatically for you."
sleep 3
cp /etc/graphite-web/local_settings.py /etc/graphite-web/local_settings.py.bk
cat << EOT >> /etc/graphite-web/local_settings.py
GRAPHITE_ROOT = '/usr/share/graphite'
CONF_DIR = '/etc/graphite-web'
STORAGE_DIR = '/var/lib/graphite-web'
CONTENT_DIR = '/usr/share/graphite/webapp/content'
WHISPER_DIR = '/var/lib/carbon/whisper/'
RRD_DIR = '/var/lib/carbon/rrd'
LOG_DIR = '/var/log/graphite-web/'

DATABASES = {
  'default': {
    'NAME': '$DBNAME',
    'ENGINE': 'django.db.backends.mysql',
    'USER': '$DBUSERNAME',
    'PASSWORD': '$DBPASS',
    'HOST': 'localhost',
    'PORT': '3306',
  }
}
SECRET_KEY = '$SECRET_KEY'
EOT

echo "Creating the necesary Grants within MySQL so that Graphite Web works"
sleep 3
mysql -e "CREATE USER '$DBUSERNAME'@'localhost' IDENTIFIED BY '$DBPASS';" -u root -p$ROOTPW
mysql -e "GRANT ALL PRIVILEGES ON $DBNAME.* TO '$DBUSERNAME'@'localhost';" -u root -p$ROOTPW
mysql -e "CREATE DATABASE $DBNAME;" -u root -p$ROOTPW
mysql -e 'FLUSH PRIVILEGES;' -u root -p$ROOTPW

echo "Syncing the Graphite Web Database"
sleep 3
/usr/lib/python2.7/site-packages/graphite/manage.py syncdb

echo "Starting Carbon Cache"
sleep 1
/etc/init.d/carbon-cache start
echo "Starting Apache"
sleep 1
/etc/init.d/httpd start

echo "Configuring Carbon Cache, MySQL, and Apache so that they start on boot"
sleep 3
chkconfig carbon-cache on
chkconfig mysqld on
chkconfig httpd on

echo "Saving a backup of the existing httpd.conf at /etc/httpd/conf/httpd.conf-bak-DATE"
sleep 3
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf-bak.$(date +%s)

echo "Automatically configuring Apache to work with Graphite Web"
sleep 3
cat << EOT >> /etc/httpd/conf/httpd.conf 
<VirtualHost *:80>

    ServerName $IPADDRESS
    DocumentRoot "/usr/share/graphite/webapp"
    ErrorLog /var/log/httpd/graphite-web-error.log
    CustomLog /var/log/httpd/graphite-web-access.log common
    Alias /media/ "/usr/lib/python2.7/site-packages/django/contrib/admin/media/"

    WSGIScriptAlias / /usr/share/graphite/graphite-web.wsgi
    WSGIImportScript /usr/share/graphite/graphite-web.wsgi process-group=%{GLOBAL} application-group=%{GLOBAL}

    <Location "/content/">
        SetHandler None
    </Location>

    <Location "/media/">
        SetHandler None
    </Location>

    <Directory "/usr/share/graphite/">
      Require all granted
    </Directory>

</VirtualHost>
EOT

echo "Restarting Apache and Carbon-Cache"
sleep 1
systemctl restart httpd
systemctl restart carbon-cache
echo "If all went well you should be able to go to http://$IPADDRESS and see the graphite interface"
echo "Keep in mind that you'll still need to setup a custom storage schema manually: /etc/carbon/storage-schemas.conf"
echo "Please RTFM here: http://graphite.readthedocs.io/en/latest/config-carbon.html"
