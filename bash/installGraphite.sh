#!/bin/bash
echo "This script should only be run on a fresh installation of Centos 7 with python 2.7 . Would you like to continue? y/n"
read CONTINUE

if [ $CONTINUE != "y" ]
    then
        exit
fi

echo "Enter the DB username for Django:"
read -e -i "graphite" DBUSERNAME
echo "Enter the DB Password:"
read DBPASS
echo "Enter the DB name for Django:"
read -e -i "graphite" DBNAME
echo "This server's public IP address (Will be added to the Apache config):"
read IPADDRESS
echo "I have generated a secret key (32 character alphanumeric) for you below. Press Enter to continue, or change it if you prefer:"
read -e -i $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1) SECRET_KEY

echo "Installing EPEL Repo and wget"
sleep 3
yum install epel-release wget -y

echo "Installing the MySQL Repository"
sleep 3
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
sudo rpm -ivh mysql-community-release-el7-5.noarch.rpm
rm -f mysql-community-release-el7-5.noarch.rpm

echo "Installing MySQL"
sleep 3
yum install mysql-server -y

echo "Installing Graphite Web"
sleep 3
yum install graphite-web -y

echo "Installing MySQL Python"
sleep 3
yum install MySQL-python -y

echo "Installing Python Carbon"
sleep 3
yum install python-carbon -y

echo "Starting the MySQL Deamon now."
sleep 3
systemctl start mysqld

echo "Starting the MySQL Secure Installation Script now."
sleep 3
mysql_secure_installation

echo "Enter the password for the root MySQL user."
read ROOTPW

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

echo "Starting Apache and Carbon-Cache"
sleep 1
systemctl start httpd
systemctl start carbon-cache
echo "If all went well you should be able to go to http://$IPADDRESS and see the graphite interface"
echo "Keep in mind that you'll still need to setup a custom storage schema manually: /etc/carbon/storage-schemas.conf"
echo "Please RTFM here: http://graphite.readthedocs.io/en/latest/config-carbon.html"
