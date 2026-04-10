#!/bin/bash

# =================================================================
# SCRIPT DE DESPLIEGUE AUTOMATIZADO - PROYECTO ECOMEDIA SOLUTIONS
# OBJETIVO: INSTALACIÓN DE STACK LAMP + WORDPRESS + PHPMYADMIN
# =================================================================

# Definición de variables de base de datos
DB_NAME="ecomedia_db"
DB_USER="eco_admin"
DB_PASS="Password_Seguro_2025"

echo "1. Iniciando actualización del sistema..."
# Actualiza los repositorios para obtener las últimas versiones de seguridad
yum update -y

echo "2. Instalando Servidor Web, Base de Datos y PHP..."
# Se instala el stack LAMP (Linux, Apache, MariaDB, PHP) y extensiones necesarias
dnf install -y mariadb105-server httpd php php-mysqlnd php-gd php-xml php-mbstring

echo "3. Activando servicios..."
# Inicia y habilita Apache y MariaDB para que arranquen con el sistema
systemctl start httpd
systemctl enable httpd
systemctl start mariadb
systemctl enable mariadb

echo "4. Configurando permisos de directorio /var/www..."
# Se asigna la propiedad al usuario ec2-user y al grupo apache
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
# Se establecen permisos 2775 para carpetas (herencia de grupo) y 0664 para archivos
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} +
find /var/www -type f -exec chmod 0664 {} +

echo "5. Creando Base de Datos y Usuario para WordPress..."
# Se automatiza la creación de la DB y el usuario mediante comandos SQL
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "6. Instalando phpMyAdmin..."
# Se descarga y descomprime la herramienta de gestión gráfica
cd /var/www/html
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
mkdir phpMyAdmin
tar -xvzf phpMyAdmin-latest-all-languages.tar.gz -C phpMyAdmin --strip-components 1
rm phpMyAdmin-latest-all-languages.tar.gz

echo "7. Descargando e instalando WordPress..."
# Descarga de la última versión oficial de WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
rm latest.tar.gz

echo "8. Configurando archivo wp-config.php..."
# Crea el archivo de configuración y reemplaza los marcadores por los datos reales
cp wordpress/wp-config-sample.php wordpress/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wordpress/wp-config.php
sed -i "s/username_here/$DB_USER/" wordpress/wp-config.php
sed -i "s/password_here/$DB_PASS/" wordpress/wp-config.php

echo "9. Inyectando llaves de seguridad (Salts) de WordPress..."
# Obtiene llaves aleatorias de la API oficial de WordPress para mayor seguridad
SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
# Elimina las líneas de salts de ejemplo y añade las reales
sed -i '/AUTH_KEY/,/NONCE_SALT/d' wordpress/wp-config.php
echo "$SALTS" >> wordpress/wp-config.php

echo "10. Optimizando configuración de Apache (AllowOverride)..."
# Modifica la configuración de Apache para permitir Permalinks (URLs amigables)
sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf

echo "11. Reiniciando servicios para aplicar cambios..."
# Reinicia el servidor web para cargar la nueva configuración de PHP y Apache
systemctl restart httpd

echo "================================================================="
echo " DESPLIEGUE FINALIZADO EXITOSAMENTE"
echo "================================================================="
echo " Acceso a WordPress: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/wordpress"
echo " Acceso a phpMyAdmin: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/phpMyAdmin"
echo "================================================================="
