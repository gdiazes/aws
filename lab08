#!/bin/bash
# Download the MySQL repository package
wget https://dev.mysql.com/get/mysql80-community-release-el9-5.noarch.rpm
# Install the MySQL repository package
sudo dnf install mysql80-community-release-el9-5.noarch.rpm -y
# Enable the MySQL community repository
sudo dnf repolist enabled | grep "mysql.*-community.*"
# Install MySQL
sudo dnf install mysql -y
