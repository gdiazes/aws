#!/bin/bash -ex
# This script is for Amazon Linux 2 or Amazon Linux 2023
# It installs a full LAMP stack with WordPress

# Update all system packages
yum update -y

# Install Apache, MySQL Community Server 8, and PHP with required modules
# The mysql-community-server package is available in the default repos for AL2023.
# For AL2, we need to add the repository first. This block handles both cases.
if ! rpm -q mysql-community-server; then
    if cat /etc/os-release | grep -q "Amazon Linux 2"; then
        wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
        yum localinstall mysql80-community-release-el7-3.noarch.rpm -y
        rm mysql80-community-release-el7-3.noarch.rpm
    fi
fi
yum install -y httpd mysql-community-server php php-mysqlnd php-gd php-xml php-mbstring

# Start and enable Apache and MySQL services
systemctl start httpd
systemctl enable httpd
systemctl start mysqld
systemctl enable mysqld

# --- Database Configuration ---
# Generate a secure, random password for the database user.
# Using a fixed password in a script is a security risk.
DB_USER="wordpress_user"
DB_NAME="wordpress_db"
# This creates a strong password and removes characters that can break configs
DB_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)

# Get the temporary root password MySQL generates on first startup
TEMP_ROOT_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | sed 's/.*root@localhost: //')

# Use the temporary password to automate the database and user creation.
# This single command block changes the root password and sets up the WP database.
mysql -u root --password="$TEMP_ROOT_PASSWORD" --connect-expired-password <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASSWORD}Root!1';
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# --- WordPress Installation and Configuration ---
# Download the latest WordPress package to the web server root
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rmdir wordpress
rm latest.tar.gz

# Create the wp-config.php file from the sample
cp wp-config-sample.php wp-config.php

# Use sed to insert the database credentials into wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" wp-config.php

# Insert unique security keys and salts from the WordPress.org API
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php

# --- Final Permissions and Cleanup ---
# Set the correct ownership and permissions for the WordPress files
chown -R apache:apache /var/www/html/
find /var/www/html/ -type d -exec chmod 755 {} \;
find /var/www/html/ -type f -exec chmod 644 {} \;

# Restart Apache to apply all changes
systemctl restart httpd
