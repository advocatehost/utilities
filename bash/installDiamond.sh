#!/bin/bash

# Capture Errors
function error(){
	echo "[ `date` ] $(tput setaf 1)$@$(tput sgr0)"
	exit $2
}

#This script needs to be run as root. Let's check to make sure.
if [[ $EUID > 0 ]]
    then error "This script must be run as root, or via sudo. Please try again with root privs."
    exit
fi

# Setup Colorful Echos

# Blue
function echo_blue(){
    echo $(tput setaf 4)$@$(tput sgr0)
}

# White
function echo_white(){
	echo $(tput setaf 7)$@$(tput sgr0)
}

# Red
function echo_red(){
    echo $(tput setaf 1)$@$(tput sgr0)
}

function install_epel(){
    release=$( grep -oE '[0-9]+\.[0-9]+' /etc/centos-release )
    echo_blue $release

    if [[ $release =~ 6\..* ]]
        then
            echo_blue "You're using centos 6. Let's grab the EPEL repo from fedoraproject.org."
            yum install wget
            wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
            rpm -ivh epel-release-6-8.noarch.rpm
            rm epel-release-6-8.noarch.rpm
        #yum update
        elif [[ $release =~ 7\..* ]]
          then
            echo_blue "You're using centos 7. This requires a simple yum installation. A moment please..."
            yum install epel-release
        #yum update
        else
            error "You're not using Centos 6 or 7. Those are the only versions that this script supports."
    fi

}

if [ -f ~/diamond.conf ]
then
    echo_blue "Using the supplied configuration file from ~/diamond.conf"
else
    error "Please add your own diamond.conf file at ~/diamond.conf . You can use the examle mentioned in the diamond docs and simply update the handler host address to get started quickly."
fi

echo_blue "Create the diamond system user."
useradd -r diamond

echo_blue "Setting up the EPEL Repository. A moment please..."

if yum repolist | grep -q "epel"
    then
        echo_blue "The EPEL repo is already installed. Moving on."
    else
        install_epel
fi


# Install required packages in one go
echo_blue "Installing the required Python packages. A moment please..."

yum install -y make python-configobj rpm-build python-pip gcc python-psutil || error "Unable to Install required python packages, Exit Status: " $?

echo_blue "Installing the Diamond collector via pip, A moment please..."

pip install diamond || error "Unable to install the Diamond collector via pip. Exit Status: " $?

if [ -f "/usr/lib/python2.6/site-packages/etc/diamond/diamond.conf.example" ]
    then
        DIAMOND_CONFIG="/usr/lib/python2.6/site-packages/etc/diamond/diamond.conf"
	elif [ -f "/usr/lib/python2.7/site-packages/etc/diamond/diamond.conf.example" ]
	    then
	        DIAMOND_CONFIG="/usr/lib/python2.7/site-packages/etc/diamond/diamond.conf"
	    else
		    error "I could not find the default diamond configuration. This probably means that you are not running python 2.6 or 2.7. You'll need to RTFM and manually configure diamond. Check this script for hints if needed."
fi

echo_blue "Creating the Diamond configuration and log directories, A moment please..."

if [ ! -d /etc/diamond ]
    then
        mkdir /etc/diamond /var/log/diamond /etc/diamond/collectors /etc/diamond/handlers /etc/diamond/user_scripts /etc/diamond/configs || error "Unable to create the Diamond configuration directories. Exit Status: " $?
        echo_white "/etc/diamond Created"
        echo_white "/var/log/diamond Created"
        echo_white "/etc/diamond/collectors Created"
        echo_white "/etc/diamond/handlers Created"
        echo_white "/etc/diamond/user_scripts Created"
        echo_white "/etc/diamond/configs Created"

fi

#Setup Default configs
echo_blue "Copying your Diamond configuration into place. A moment please..."

# the \ before a command overrides any aliases. In this case we are overriding any aliases that would force us to confirm overwriting the config files, thus breaking the automatic nature of this script.
\cp -f ~/diamond.conf $DIAMOND_CONFIG || error "Unable to copy diamond.conf from ~/diamond.conf to $DIAMOND_CONFIG . You will need to RTFM and supply your own diamond configuration file at ~/diamond.conf to continue . Exit Status:" $?

#To be brutally honest, I'm don't remember why I softlink this config instead of just placing it directly. This mayhaps could use some refactoring after I RTFM some more.
ln -f -s $DIAMOND_CONFIG /etc/diamond || error "Unable to softlink from $DIAMOND_CONFIG to /etc/diamond/diamond.conf. Exit Status:" $?

#I'll update this later so that I can include a better collector config.
# \cp -f ./collectorConfigs/CPUCollector.conf /etc/diamond/collectors/ || error "Unable to copy CPUCollector.conf, exit status " $?

#Set it up as a service
echo_blue "Configuring Diamond as a service via an init script. A moment please..."

#The below seems to be done automatically by Diamond. At least on Centos 7. Unfortunatley the init script does not work.
#curl https://raw.githubusercontent.com/python-diamond/Diamond/master/debian/diamond.init --output diamond.init
#\cp -f ./diamond.init /etc/init.d/diamond || error "Unable to place the diamond init script into /etc/init.d/diamond. Exit Status:" $?
#chmod 0755 /etc/init.d/diamond || error "Unable to update diamond init script permissions to 0755. Exit Status:" $?
#chown root:root /etc/init.d/diamond || error "Unable to update diamond init script ownership to root:root. Exit Status:" $?
#chkconfig diamond on || error "Unable to set chkconfig diamond on. Exit Status:" $?

echo_blue "Restarting the Diamond collector. A moment please..."
service diamond restart || error "Unable to restart diamond. Exit Status:" $?
echo
echo
echo
echo
echo_blue "Diamond has been installed and started."
echo_blue "The Diamond collector is sending statistics to the handler that you have configured right now. Please allow a few moments and check."
echo_blue "To enable more collectors run diamond-setup"

