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

if [ -f /root/diamond.conf ]
then
    echo_blue "Using the supplied configuration file from /root/diamond.conf"
else
    error "Please add your own diamond.conf file at /root/diamond.conf . There is an great example configuration to work from on the python-diamond github."
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

echo_blue "Creating the Diamond configuration dirs and log dirs, and the log file. A moment please..."

if [ ! -d /etc/diamond ]
    then
        mkdir /etc/diamond /var/log/diamond /etc/diamond/collectors /etc/diamond/handlers /etc/diamond/user_scripts /etc/diamond/configs || error "Unable to create the Diamond configuration directories. Exit Status: " $?

        #I don't really like adding this archive log, because I don't use it, but the Archive log is setup as an active handler in the default config. If this log file does not exist with the correct ownership, diamond will fail to start. 
        touch /var/log/diamond/archive.log
        chown diamond:diamond /var/log/diamond/archive.log
        echo_white "/etc/diamond Created"
        echo_white "/var/log/diamond Created"
        echo_white "/etc/diamond/collectors Created"
        echo_white "/etc/diamond/handlers Created"
        echo_white "/etc/diamond/user_scripts Created"
        echo_white "/etc/diamond/configs Created"
        echo_white "/var/log/diamond/archive.log Created"

fi

#Setup Default configs
echo_blue "Copying your Diamond configuration into place. A moment please..."

# the \ before a command overrides any aliases. In this case we are overriding any aliases that would force us to confirm overwriting the config files, thus breaking the automatic nature of this script.
\cp -f /root/diamond.conf /etc/diamond || error "Unable to copy /root/diamond.conf to /etc/diamond/diamond.conf Exit Status:" $?

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
echo_blue "The Diamond collector is sending statistics to the handler(s) that you have configured as you read this. Please allow a few moments and check."
echo_blue "To enable more collectors run diamond-setup"

