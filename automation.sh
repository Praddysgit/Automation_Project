#!/bin/bash

# Declaring variables
myname='pramod'
s3_bucket='upgrad-pramod'
timestamp=$(date '+%d%m%Y-%H%M%S')
sudo apt-get update -y
if !(systemctl --all --type service | grep  "apache2");
then
    sudo apt-get install apache2 -y
fi
sudo service apache2 status
if [ $? != 0 ];
then
	sudo service apache2 start
fi
if (sudo systemctl status apache2.service | grep 'disabled');
then
	sudo systemctl enable apache2.service
fi
tar -czvf /tmp/${myname}-httpd-logs-${timestamp}.tar /var/log/apache2/*.log
aws s3 \
cp /tmp/${myname}-httpd-logs-${timestamp}.tar \
s3://${s3_bucket}/${myname}-httpd-logs-${timestamp}.tar