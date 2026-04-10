
# Examen Final: Despliegue de Infraestructura de Gestión de Contenidos (CMS) en AWS

## 1. Contexto del Caso: "Proyecto Digital Connect"
La organización sin fines de lucro **"Digital Connect"** requiere establecer una presencia web robusta para difundir sus informes anuales. El departamento de TI ha decidido que, por razones de control y personalización, se evitarán los servicios gestionados de terceros y se optará por una arquitectura propia sobre Amazon Web Services.

**El Desafío:** Como Administrador de Sistemas Cloud (SysAdmin), se le solicita desplegar un servidor web monolítico que albergue un sitio **WordPress**. La solución debe ser instalada "desde cero" utilizando el stack **LAMP** (Linux, Apache, MariaDB, PHP) sobre una instancia de cómputo elástico, garantizando que el sitio sea accesible globalmente y que la base de datos esté correctamente securizada.


## 2. Objetivos de Evaluación
*   Configuración y aprovisionamiento de cómputo elástico (EC2).
*   Gestión de redes y seguridad mediante Security Groups.
*   Administración de servidores Linux vía SSH.
*   Instalación y configuración del stack de software web (LAMP).
*   Despliegue y puesta en marcha de una aplicación de nivel de producción (WordPress).


## 3. Guía Paso a Paso (Procedimiento Técnico)

### Fase I: Aislamiento y Preparación de la Infraestructura
1.  Es realizada la conexión a la **Consola de Administración de AWS** en la región **us-east-1 (N. Virginia)**.
2.  Es creado un **Security Group** denominado `SG-DigitalConnect-Web`. Se deben habilitar las reglas de entrada para los puertos **22 (SSH)** para administración y **80 (HTTP)** para tráfico web público.
3.  Se procede al lanzamiento de una instancia **EC2** denominada `SRV-WordPress-Prod`.
    *   **AMI:** Amazon Linux 2023.
    *   **Tipo de Instancia:** `t2.micro`.
    *   **Red:** Es habilitada la asignación de IP pública y se asocia el Security Group creado anteriormente.
    *   **Key Pair:** Es generada o seleccionada una llave RSA para el acceso seguro.

### Fase II: Preparación del Entorno de Servidor (Stack LAMP)
1.  Se establece una conexión mediante el protocolo **SSH** hacia la dirección IP pública de la instancia.
2.  Es ejecutada una actualización de los repositorios del sistema para asegurar la integridad de los paquetes.
3.  **Instalación del Servidor Web:** Es instalado el servidor **Apache** (`httpd`). Posteriormente, el servicio es iniciado y configurado para su ejecución automática tras reinicios del sistema.
4.  **Instalación del Motor de Base de Datos:** Se procede con la instalación de **MariaDB**. Una vez activo, es ejecutado el script de seguridad para definir la contraseña del usuario raíz y remover privilegios de acceso anónimo.
5.  **Instalación de Lenguaje de Scripting:** Es instalado **PHP** junto con las extensiones necesarias para la comunicación con bases de datos y el procesamiento de gráficos requeridos por el CMS.

 ```bash
sudo yum update -y
sudo dnf install -y mariadb105-server php php-mysqlnd httpd
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl is-enabled httpd
sudo usermod -a -G apache ec2-user
sudo chown -R ec2-user:apache /var/www
sudo chmod 2775 /var/www && find /var/www -type d -exec sudo chmod 2775 {} \;
find /var/www -type f -exec sudo chmod 0664 {} \;
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
```


### Fase III: Configuración de la Base de Datos
1.  Se accede a la consola de MariaDB.
2.  Es creada una base de datos denominada `db_wordpress_prod`.
3.  Es generado un usuario de base de datos llamado `user_admin_wp` con una contraseña robusta.
4.  Son concedidos todos los privilegios sobre la base de datos creada al nuevo usuario para permitir la persistencia de datos del CMS.
 ```bash
sudo systemctl start mariadb
```
```bash
sudo mysql_secure_installation
```
```bash
Y
```
```bash
sudo systemctl enable mariadb
```
```bash
sudo yum install php-mbstring php-xml -y
```
```bash
sudo systemctl restart httpd
```
```bash
sudo systemctl restart php-fpm```
```



### Fase IV: Despliegue de la Aplicación WordPress
1.  El paquete de instalación de **WordPress** es descargado desde su fuente oficial y extraído en el directorio raíz del servidor web (`/var/www/html/`).
2.  Es creado el archivo de configuración `wp-config.php` a partir de la plantilla suministrada. En este archivo, son definidos los parámetros de conexión (nombre de la base de datos, usuario y contraseña) establecidos en la Fase III.
3.  Son ajustados los permisos de archivos y directorios para permitir que el servidor Apache pueda gestionar las subidas de contenido y la instalación de complementos.
4.  Se configuran los **Permalinks** (enlaces permanentes) para optimizar la estructura de las URLs del sitio.

### Fase V: Validación y Entrega
1.  Se accede a la dirección IP pública de la instancia desde un navegador web.
2.  Es completado el script de instalación visual de WordPress, definiendo el título del sitio y las credenciales del administrador.
3.  Se verifica que el sitio web sea plenamente funcional y que el acceso al panel de administración (`/wp-admin`) sea exitoso.


## 4. Criterios de Calificación
| Elemento | Indicador de Éxito | Porcentaje |
| :--- | :--- | :---: |
| **Seguridad de Red** | Acceso restringido solo a puertos 22 y 80. | 15% |
| **Stack LAMP** | Funcionamiento correcto de Apache, PHP y MariaDB. | 30% |
| **Persistencia de Datos** | Creación exitosa de base de datos y usuario vinculado. | 25% |
| **Funcionalidad CMS** | WordPress instalado y accesible por IP pública. | 30% |

---

## 5. Cierre del Laboratorio
Una vez finalizada la evaluación y validados los resultados por el instructor, se debe proceder a la **terminación de la instancia EC2** y la eliminación del **Security Group** para evitar costos residuales y mantener la limpieza del entorno de nube.
