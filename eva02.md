### Despliegue de una Aplicación Web Segura


#### **1. El Escenario**

Imagina que estamos desarrollando una aplicación web (por ejemplo, un blog, una tienda online o un sistema de gestión de clientes). La arquitectura de la aplicación tiene dos componentes principales:

*   **El Servidor de Aplicación (Frontend/Backend):** El código que se ejecuta, procesa las solicitudes de los usuarios y muestra las páginas web. Lo desplegaremos en una instancia **Amazon EC2**.
*   **La Base de Datos (Persistencia):** Donde se almacenan todos los datos críticos: usuarios, productos, artículos, etc. Utilizaremos **Amazon RDS** para esto.

**Objetivo:** Conectar de forma segura el servidor de aplicación (EC2) a la base de datos (RDS), protegiendo la base de datos de accesos no autorizados desde Internet.

#### **2. La Arquitectura Propuesta (La Mejor Práctica)**

La clave de este laboratorio es seguir la mejor práctica de seguridad de AWS: **nunca exponer una base de datos directamente a Internet**.

*   **Instancia EC2 en Subred Pública:** El servidor web se ubicará en una `subred pública`. Esto significa que tendrá una dirección IP pública y estará conectado a un *Internet Gateway*. Esto es necesario para que los usuarios de Internet puedan acceder a nuestra aplicación web (por ejemplo, a través del puerto 80 para HTTP).
*   **Instancia RDS en Subredes Privadas:** La base de datos RDS se desplegará en un `grupo de subredes privadas`. Estas subredes **no** tienen una ruta directa a Internet. Esto significa que la base de datos no tendrá una IP pública y será inaccesible desde el exterior, protegiéndola de ataques de fuerza bruta, inyecciones SQL remotas y otros riesgos.

**¿Cómo se comunican entonces?** A través de la red interna de la VPC, controlada por **Grupos de Seguridad**.



#### **3. Plan de Acción Detallado (Paso a Paso)**

Siguiendo el laboratorio, estos serían los pasos y la lógica detrás de cada uno:

**Paso 1: Configurar la Red (VPC)**
1.  **Crear una VPC:** El entorno de red aislado para nuestros recursos.
2.  **Crear Subredes:**
    *   Una o más **subredes públicas** (ej. `public-subnet-1a`).
    *   Dos o más **subredes privadas** en diferentes Zonas de Disponibilidad (ej. `private-subnet-1a`, `private-subnet-1b`). RDS requiere al menos dos para la alta disponibilidad (Multi-AZ).
3.  **Configurar Ruteo:**
    *   Crear un **Internet Gateway** y adjuntarlo a la VPC.
    *   Modificar la tabla de rutas de la subred pública para dirigir el tráfico de Internet (`0.0.0.0/0`) hacia el Internet Gateway.
    *   La tabla de rutas de las subredes privadas **no** se modifica para que no tengan acceso directo a Internet.

**Paso 2: Configurar la Seguridad (Grupos de Seguridad)**
Esta es la parte más importante para la conexión. Crearemos dos grupos de seguridad:

1.  **Grupo de Seguridad para el Servidor Web (`sg-webapp`)**:
    *   **Regla de Entrada 1:** Permitir tráfico HTTP (puerto 80) desde cualquier lugar (`0.0.0.0/0`).
    *   **Regla de Entrada 2:** Permitir tráfico SSH (puerto 22) solo desde tu IP, para que puedas administrar el servidor.

2.  **Grupo de Seguridad para la Base de Datos (`sg-database`)**:
    *   **Regla de Entrada CLAVE:** Permitir tráfico en el puerto de la base de datos (ej. **MySQL/Aurora: 3306**, **PostgreSQL: 5432**) **únicamente** desde el grupo de seguridad `sg-webapp`.
    *   *Nota del especialista:* Esta es la forma correcta de hacerlo. En lugar de usar la IP de la instancia EC2 (que puede cambiar), referenciamos su grupo de seguridad. Cualquier instancia que esté en `sg-webapp` podrá comunicarse con la base de datos.

**Paso 3: Lanzar la Base de Datos RDS**
1.  Ve al servicio RDS y crea una nueva base de datos (ej. MySQL).
2.  **Configuración de Red:** Elige la VPC que creaste.
3.  **Grupo de Subredes:** RDS te pedirá que crees un grupo de subredes. Selecciona las **subredes privadas** (`private-subnet-1a`, `private-subnet-1b`).
4.  **Grupo de Seguridad:** Asigna el grupo de seguridad `sg-database`.
5.  Completa el resto de la configuración (nombre de usuario, contraseña, etc.) y lanza la instancia. Una vez creada, anota su **endpoint** (ej. `my-db.random-chars.us-east-1.rds.amazonaws.com`).

**Paso 4: Lanzar el Servidor Web EC2**
1.  Ve al servicio EC2 y lanza una nueva instancia (ej. Amazon Linux 2).
2.  **Configuración de Red:** Elige la misma VPC y la **subred pública** (`public-subnet-1a`).
3.  **Habilitar IP Pública:** Asegúrate de que se le asigne una IP pública.
4.  **Grupo de Seguridad:** Asigna el grupo de seguridad `sg-webapp`.
5.  Lanza la instancia.

**Paso 5: Probar la Conexión**
1.  Conéctate a tu instancia EC2 mediante SSH.
2.  Desde la terminal de la EC2, instala un cliente de base de datos (ej. `sudo yum install mysql -y`).
3.  Intenta conectarte a la base de datos RDS usando el endpoint que anotaste:
    ```bash
    mysql -h [endpoint-de-tu-rds] -u [tu-usuario] -p
    ```
4.  ¡Debería funcionar! La EC2, al estar en `sg-webapp`, tiene permiso para acceder a la RDS en el puerto 3306.

**Prueba de Seguridad:** Si intentas realizar este mismo comando `mysql` desde tu ordenador local, **fallará**. Esto demuestra que la base de datos está correctamente aislada y protegida de Internet.

Este caso práctico demuestra una arquitectura robusta, segura y escalable, que es el estándar de la industria para desplegar aplicaciones en AWS. ¡Si tienes alguna duda sobre algún paso, no dudes en preguntar
