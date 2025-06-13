#!/bin/bash -ex
# Script para instalar WordPress + phpMyAdmin en Amazon Linux 2/2023

# --- PERSONALIZA TU CONFIGURACIÓN AQUÍ ---
# ADVERTENCIA: Usar contraseñas fijas es un riesgo de seguridad.
# Se recomienda solo para entornos de prueba o desarrollo.

DB_NAME="dbwordpress"
DB_USER="admin"
DB_PASS="Tecsup00--"

# --- FIN DE LA ZONA DE PERSONALIZACIÓN ---


# --- Instalación de la Pila de Software ---
# Actualizar todos los paquetes del sistema
yum update -y

# Instalar Apache, MySQL Community Server 8 y PHP con los módulos necesarios
if ! rpm -q mysql-community-server; then
    if cat /etc/os-release | grep -q "Amazon Linux 2"; then
        wget https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm
        yum localinstall mysql80-community-release-el7-3.noarch.rpm -y
        rm mysql80-community-release-el7-3.noarch.rpm
    fi
fi
yum install -y httpd mysql-community-server php php-mysqlnd php-gd php-xml php-mbstring

# Habilitar el repositorio EPEL para instalar phpMyAdmin
if cat /etc/os-release | grep -q "Amazon Linux 2023"; then
    dnf install -y epel-release
else
    amazon-linux-extras install epel -y
fi
yum install -y phpmyadmin


# --- Configuración de la Base de Datos ---
# Iniciar y habilitar servicios
systemctl start httpd
systemctl enable httpd
systemctl start mysqld
systemctl enable mysqld

# Obtener la contraseña temporal de root de MySQL
TEMP_ROOT_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | sed 's/.*root@localhost: //')

# Automatizar la configuración de la base de datos usando las variables personalizadas
mysql -u root --password="$TEMP_ROOT_PASSWORD" --connect-expired-password <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF


# --- Instalación y Configuración de WordPress ---
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
mv wordpress/* .
rmdir wordpress
rm latest.tar.gz

# Crear y configurar wp-config.php con las variables personalizadas
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASS/" wp-config.php

# Insertar claves de seguridad únicas de la API de WordPress.org
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php


# --- Configuración de phpMyAdmin ---
# Permitir el acceso a phpMyAdmin desde cualquier dirección IP
sed -i 's/Require ip 127.0.0.1/Require all granted/' /etc/httpd/conf.d/phpMyAdmin.conf
sed -i 's/Require ip ::1/ /' /etc/httpd/conf.d/phpMyAdmin.conf


# --- Permisos Finales y Reinicio ---
# Establecer propietario y permisos correctos para los archivos web
chown -R apache:apache /var/www/html/
find /var/www/html/ -type d -exec chmod 755 {} \;
find /var/www/html/ -type f -exec chmod 644 {} \;

# Reiniciar Apache para que todos los cambios surtan efecto
systemctl restart httpd
