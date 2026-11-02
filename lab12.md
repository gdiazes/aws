# Guía de Laboratorio 12: 
## Respaldo y Recuperación de Bases de Datos en Amazon RDS con Snapshots

* **Rol que asumirás:** Ingeniero de Bases de Datos Cloud (Cloud Database Engineer)
* **Tiempo disponible:** 2 horas (Tiempo real de ejecución: ~45 minutos)
* **Región obligatoria de AWS:** `us-east-1` (US East - N. Virginia)
* **Herramienta requerida en tu PC:** [MySQL Workbench](https://dev.mysql.com/downloads/workbench/) instalado.

---

## 1.A. Topología de Infraestructura (¿Dónde vive cada componente en AWS?)

Antes de hacer clic en la consola, observa este mapa completo. Muestra todos los componentes técnicos que existen desde tu computadora hasta el disco duro donde se guardarán tus datos en AWS (sin omitir ningún elemento de red o seguridad):

```text
====================================================================================================
[ ENTORNO LOCAL DEL ESTUDIANTE (Tu Computadora / Laptop) ]
  │
  ├── Usuario Administrador (user)
  ├── Navegador Web -> AWS Management Console (Tráfico de administración HTTPS / Puerto 443)
  ├── Cliente SQL -> MySQL Workbench (GUI Tool) + MySQL credentials (Usuario y Contraseña)
  └── Dirección IP Pública de tu Internet (Ej. 190.x.x.x/32)
        │
        │ (Tráfico de Base de Datos: Protocolo TCP por el Puerto 3306)
        ▼
====================================================================================================
[ AWS CLOUD (Cuenta del Laboratorio - Región: us-east-1 N. Virginia) ]
  │
  ├── Identidad y Orquestación (Plano de Control):
  │     ├── IAM (Identity and Access Management): Valida tu "Login to AWS Console"
  │     └── Servicio Amazon RDS: El "cerebro" que crea bases de datos, toma fotos (Snapshots) y restaura.
  │
  ├── Almacenamiento Regional de Backups (Gestionado por AWS sobre Amazon S3):
  │     └── RDS Snapshots ("xyz-snapshot-backup")
  │           ├── Contenido: Fotografía exacta del sistema, bases de datos y la tabla ("Table: clientes")
  │           └── Cifrado: AWS KMS (Key Management Service)
  │
  └── Red Privada Virtual por Defecto (Default VPC - Rango IP: 172.31.0.0/16)
        │
        ├── Internet Gateway (IGW): La puerta que conecta la VPC con Internet.
        ├── Tabla de Enrutamiento Pública (Route Table): Dirige el tráfico externo (0.0.0.0/0) hacia el IGW.
        ├── Grupo de Subredes RDS (DB Subnet Group "default"): Subredes en zonas us-east-1a, 1b, 1c...
        │
        └── Zona de Disponibilidad A (us-east-1a) [Arquitectura Single-AZ (1 solo centro de datos)]
              └── Subred Pública (Public Subnet)
                    └── Firewall Virtual: VPC Security Group ("rds-public-sg")
                          │  *Regla de Entrada (Inbound): Permite puerto 3306 desde cualquier IPv4 (0.0.0.0/0)*
                          │
                          ├── [1] MySQL DB instance [ORIGEN] (Nombre: "mysql-origen")
                          │     ├── Motor: MySQL Community | Tamaño: Burstable (db.t3.micro / db.t2.micro)
                          │     ├── Acceso Público: Sí (Public Access: Yes)
                          │     ├── Dirección (Endpoint DNS 1): mysql-origen.[id].us-east-1.rds.amazonaws.com
                          │     ├── Disco Duro (EBS): 20 GiB (Tipo gp2 / gp3)
                          │     └── Base de Datos ("empresa_xyz") ──> Table ("clientes")
                          │
                          └── [2] Restored Instance - MySQL DB instance [DESTINO] (Nombre: "mysql-restaurada")
                                ├── Origen: Creada a partir de "RDS Snapshots"
                                ├── Motor: MySQL Community | Tamaño: Burstable db.t3.micro
                                ├── Acceso Público: Sí (Public Access: Yes)
                                ├── Dirección NUEVA (Endpoint DNS 2): mysql-restaurada.[id].us-east-1.rds.amazonaws.com
                                ├── Disco Duro Nuevo (EBS): 20 GiB (Tipo gp2)
                                └── Base de Datos Clonada ("empresa_xyz") ──> Table Recuperada ("clientes")
====================================================================================================
```

---

## 1.B. Topología del Flujo de Trabajo (El Mapa de Ruta de tu Reto)

Este diagrama traduce el esquema gráfico del laboratorio en una secuencia numerada del **`(1)` al `(6)`**. Cada número corresponde exactamente a un paso que harás más abajo en la guía:

```text
+----------------------------------------------------------------------------------------------------------+
| [ TU COMPUTADORA ]                             |                     [ AWS CLOUD ]                       |
|                                                |                                                         |
|   [ user ] (Tú)                                |          +-----------------------------------+          |
|        │                                       |          |        [ Restored Instance ]      |          |
|        │ (1) Login to AWS Console              |          |  MySQL DB instance (Restaurada)   |          |
|        ▼                                       |          |     ├── Dirección DNS Nueva       |          |
|   [ AWS Management Console ]                   |          |     └── Table (Recuperada)        |          |
|        │                                       |          +-----------------▲-----------------+          |
|        │ (2) Create and Configure              |                            │                            |
|        +---------------------------------------+------------> [ Amazon RDS (Servicio) ]                  |
|                                                |               │            │       ▲                    |
|                                                |               │            │       │ (5) Restore from   |
|                                                |               │            │       │     Snapshot       |
|                                                |               │            │       ▼                    |
|                                                |               │         [ RDS Snapshots ]               |
|                                                |               │                    ▲                    |
|                                                |               │ (2.1) Construye    │ (4) Take           |
|                                                |               │       Servidor     │     Snapshot       |
|                                                |               ▼                    │                    |
|   [ MySQL Workbench ]                          |          +-------------------------+---------+          |
|        │                                       |          |        [ Instancia Origen ]       |          |
|        │ (3) y (6) MySQL login                 |          |  MySQL DB instance (Original)     |          |
|        ▼                                       |          |     └── Dirección DNS Original    |          |
|   [ MySQL credentials ]                        |          +-----------------▲-----------------+          |
|        │  (Usuario: admin / Contraseña)        |                            │                            |
|        │                                       |                            │ (3.2) Crea y guarda datos  |
|        +--(3.1) Conexión Inicial (Puerto 3306)-+----------------------------+       [ Table ]            |
|        │                                       |                                                         |
|        +--(6.1) Conexión Final de Prueba-------+--(Hacia la dirección DNS de Restored Instance - P. 3306)|
+----------------------------------------------------------------------------------------------------------+
```

---

## 2. El Reto de Negocio (¿Por qué estamos haciendo esto?)

> **Situación:** La empresa **XYZ** tiene su base de datos en **Amazon RDS**. Hoy van a realizar una actualización peligrosa en el sistema y tienen miedo de perder la información de sus clientes si algo sale mal.
> 
> **Tu Misión:** 
> 1. Crear la base de datos principal de la empresa, conectarte a ella desde tu computadora y guardar una tabla con datos de prueba.
> 2. Tomarle una "fotografía de seguridad" (**Snapshot**) a toda la base de datos.
> 3. Demostrar que esa fotografía sirve: usarás el Snapshot para crear un **segundo servidor de base de datos totalmente nuevo** (Restored Instance) y te conectarás a él para comprobar que los datos siguen ahí.

---

## 3. Guía Paso a Paso (A Prueba de Errores)

Sigue las instrucciones en orden. Fíjate cómo cada etapa hace referencia a los números del diagrama **1.B**.

---

### ETAPA 1: Iniciar el Entorno y Entrar a AWS `(Flujo 1: Login to AWS Console)`

1. En el panel de control de tu entorno de laboratorio, inicia el reto (**Start Challenge**) y espera menos de un minuto a que se generen tus credenciales temporales.
2. Haz clic en el botón **Open Console**. Se abrirá una pestaña nueva con el inicio de sesión de AWS.
3. **CUIDADO AQUÍ (Regla de Oro):** 
   * Verás un campo llamado **Account ID** (con 12 números). **NO lo borres ni lo cambies**, déjalo tal como está.
   * Copia el **IAM Username** proporcionado en el panel del laboratorio y pégalo en AWS.
   * Copia el **Password** proporcionado en el panel del laboratorio y pégalo en AWS.
   * Haz clic en **Sign in**.
4. **Verificar la Región:** Ya dentro de AWS, mira la barra superior derecha (al lado del nombre de tu usuario). Debe decir **N. Virginia** o **US East (N. Virginia) `us-east-1`**. Si dice otra ciudad (como Ohio o Oregon), haz clic ahí y cámbialo a **US East (N. Virginia)**.

---

### ETAPA 2: Crear la Base de Datos Principal `(Flujo 2: Create and Configure)`

Vamos a pedirle a Amazon RDS que construya nuestro primer servidor de base de datos.

1. En la barra de búsqueda superior de AWS, escribe **`RDS`** y haz clic en el servicio **Aurora and RDS**.
2. En el menú de la izquierda, haz clic en **Databases** (Bases de datos) y luego en el botón naranja **Create database** (Crear base de datos).
3. Configura el formulario bajando poco a poco por la página (si no menciono una opción, déjala como viene por defecto):

   * **Sección 1 - Choose a database creation method:**
     * Selecciona **Standard create** (Creación estándar). *(Importante: Si dejas "Easy create", AWS esconderá el botón de acceso público y fallarás el laboratorio).*
   
   * **Sección 2 - Engine options (Motor):**
     * Elige **MySQL**.
     * Abajo en *Edition*, verifica que diga **MySQL Community**.

   * **Sección 3 - Templates (Plantillas):**
     * Selecciona **Free tier** (Capa gratuita) o **Dev/Test**.
     * *Nota:* Si eliges **Dev/Test**, aparecerá justo debajo la sección **Availability and durability**. Ahí debes marcar obligatoriamente **Single DB instance** (Una sola instancia / Single-AZ). *(Si elegiste Free tier, AWS ya lo pone en Single-AZ automáticamente).*

   * **Sección 4 - Settings (Nombres y Contraseña):**
     * **DB instance identifier** (Nombre del servidor en AWS): Escribe **`mysql-origen`**
     * **Master username** (Usuario de la base de datos): Escribe **`admin`**
     * **Credentials management** (Gestión de credenciales): Marca **Self managed** (Autoadministrado). *(Atención: No dejes marcado "Managed in AWS Secrets Manager" porque no te dejará escribir tu propia contraseña).*
     * **Master password** y **Confirm password**: Escribe **`Admin12345!`** en ambos cuadros. *(Anota esta contraseña, la usarás en MySQL Workbench).*

   * **Sección 5 - Instance configuration (Tamaño del servidor):**
     * Marca la opción **Burstable classes (includes t classes)**.
     * En la lista desplegable, busca **`db.t2.micro`**.
     * *Nota de Especialista:* Como las versiones nuevas de MySQL en AWS ya jubilaron la familia `t2`, si no aparece `db.t2.micro` en la lista, selecciona **`db.t3.micro`**.

   * **Sección 6 - Storage (Disco duro):**
     * **Storage type:** Abre la lista y selecciona **General Purpose SSD (gp2)**.
     * **Allocated storage:** Escribe **`20`** (GiB).
     * Desmarca la casilla *Enable storage autoscaling* (para evitar cambios automáticos).

   * **Sección 7 - Connectivity (Conectividad a Internet - MUY IMPORTANTE):**
     * En **Public access** (Acceso público): Marca **`Yes`** (Sí). *(Por defecto viene en "No". Si no lo cambias a "Yes", tu computadora jamás podrá encontrar la base de datos por Internet).*
     * En **VPC security group (firewall)**: Marca **Create new** (Crear nuevo).
     * En **New VPC security group name**: Escribe **`rds-public-sg`**

   * **Sección 8 - Additional configuration (Al final de la página):**
     * Haz clic en la flecha de **Additional configuration** para abrir las opciones ocultas.
     * En **Initial database name**: Escribe **`empresa_xyz`** *(sin espacios ni guiones medios)*.
     * En **Backup**: Desmarca la casilla *Enable automated backups* (no necesitamos respaldos automáticos hoy porque haremos el Snapshot manualmente, y desmarcar esto ahorra tiempo de espera).

4. Haz clic en el botón naranja final **Create database**.
5. **Paciencia:** Verás tu base de datos `mysql-origen` en la lista con el estado `Creating` (Creando). Tardará unos **5 minutos** en cambiar al estado verde **`Available`** (Disponible).

---

### ETAPA 3: Abrir el Firewall para cualquier IPv4 `(Requisito de Red)`

Mientras la base de datos termina de crearse, vamos a asegurarnos de que el firewall (`rds-public-sg`) cumpla con la regla del laboratorio: *"permitir tráfico entrante desde cualquier dirección IPv4"*.

1. En la lista de bases de datos, haz clic sobre el nombre azul **`mysql-origen`**.
2. Baja un poco y asegúrate de estar en la pestaña **Connectivity & security**.
3. A la derecha, bajo el título **VPC security groups**, haz clic sobre el enlace azul **`rds-public-sg`**. (Esto abrirá la pantalla de Security Groups).
4. Abajo, haz clic en la pestaña **Inbound rules** (Reglas de entrada) y luego a la derecha en el botón **Edit inbound rules**.
5. Verás una regla para `MYSQL/Aurora` (Puerto `3306`). En la columna **Source** (Origen), si ves una IP con números, bórrala haciendo clic en la `x`, elige en el desplegable **Anywhere-IPv4** (se escribirá **`0.0.0.0/0`**).
6. Haz clic en el botón naranja **Save rules** (Guardar reglas).
7. Cierra esta pestaña o vuelve a la pantalla de **Amazon RDS -> Databases**.

---

### ETAPA 4: Conectarse con MySQL Workbench y Crear la Tabla `(Flujo 3: MySQL login & Table)`

Verifica que tu base de datos `mysql-origen` ya diga **`Available`** en verde.

1. Entra a **`mysql-origen`** y en la pestaña **Connectivity & security**, copia el texto debajo de **Endpoint** (se ve algo así: `mysql-origen.c9xyz123.us-east-1.rds.amazonaws.com`). *Cópialo completo sin espacios.*
2. Abre el programa **MySQL Workbench** en tu computadora.
3. Junto al título *MySQL Connections*, haz clic en el botón **`+`** para crear una conexión nueva y llena estos datos:
   * **Connection Name:** `1 - Base de Datos Origen`
   * **Hostname:** Pega aquí el **Endpoint** que acabas de copiar de AWS.
   * **Port:** `3306`
   * **Username:** `admin`
   * **Password:** Haz clic en el botón **Store in Vault...** (o *Store in Keychain...* en Mac), escribe **`Admin12345!`** y dale a OK.
4. Haz clic abajo en **Test Connection**. Te saldrá un cuadro diciendo *"Successfully made the MySQL connection"*. Dale a **OK** y luego a **OK** para guardar.
5. Haz doble clic sobre el recuadro gris `1 - Base de Datos Origen` que se creó en MySQL Workbench para entrar al servidor.
6. En la pantalla blanca de código (Query), copia y pega estas líneas para ver las bases de datos y crear nuestra **`Table`** del diagrama:

```sql
-- 1. Ver la lista de bases de datos accesibles (Requisito del paso 2)
SHOW DATABASES;

-- 2. Entrar a la base de datos de la empresa y crear una tabla con datos reales
USE empresa_xyz;

CREATE TABLE clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50),
    correo VARCHAR(50)
);

INSERT INTO clientes (nombre, correo) VALUES ('Ana Torres', 'ana@xyz.com');
INSERT INTO clientes (nombre, correo) VALUES ('Carlos Ruiz', 'carlos@xyz.com');

-- 3. Mostrar la tabla creada con sus datos
SELECT * FROM clientes;
```

7. Selecciona todo el código y haz clic en el icono del **Rayo** en la barra de herramientas superior del editor para ejecutarlo. Verás abajo la lista de bases de datos y la tabla con Ana y Carlos.

---

### ETAPA 5: Tomar la Fotografía de Seguridad `(Flujo 4: Take Snapshot)`

Ahora que nuestra base de datos tiene información valiosa, vamos a respaldarla en AWS.

1. Regresa a tu navegador web en **Amazon RDS -> Databases**.
2. Marca el círculo a la izquierda de **`mysql-origen`**.
3. Arriba a la derecha, haz clic en el botón **Actions** (Acciones) y elige **Take snapshot** (Tomar instantánea).
4. En el campo **Snapshot name**, escribe: **`xyz-snapshot-backup`**
5. Haz clic en el botón naranja **Take snapshot**.
6. AWS te llevará automáticamente a la pantalla de **Snapshots**.
7. **ALTO AQUÍ (Espera obligatoria):** Mira la columna **Status** de tu snapshot `xyz-snapshot-backup`. Dirá `Creating` (Creando). **No hagas nada hasta que cambie a `Available` (Disponible) en color verde** (tarda unos 3 minutos). Puedes darle al botón de refrescar arriba a la derecha.

---

### ETAPA 6: Restaurar el Snapshot en un Nuevo Servidor `(Flujo 5: Restore from Snapshot)`

> **Concepto Clave que debes saber:** En AWS, restaurar un Snapshot **NO** reemplaza tu base de datos anterior. Lo que hace es **crear una segunda base de datos nueva** con una copia exacta de lo que había en la foto. *(En algunas guías en inglés a este paso le llaman "Create Backup Configuration", pero en AWS el botón real se llama "Restore snapshot").*

1. En la pantalla de **Snapshots**, cuando `xyz-snapshot-backup` ya diga **`Available`**, márcalo haciendo clic en el cuadrito a su izquierda.
2. Arriba a la derecha, haz clic en **Actions** y selecciona **Restore snapshot** (Restaurar instantánea).
3. Llena los datos para esta **nueva** base de datos siguiendo exactamente las reglas del laboratorio:

   * **Engine:** Verifica que diga **MySQL Community**.
   * **Availability and durability (Deployment options):** Marca **Single DB instance** (Una sola instancia). *(Cuidado: AWS a veces marca Multi-AZ por defecto aquí; asegúrate de cambiarlo a Single DB instance).*
   * **Settings -> DB instance identifier** (Nombre para la base de datos nueva): Escribe **`mysql-restaurada`**
   * **Instance configuration (Tamaño):**
     * Marca **Burstable classes (includes t classes)**.
     * En la lista desplegable selecciona **`db.t3.micro`**.
   * **Storage (Almacenamiento):**
     * **Storage type:** Selecciona **General Purpose SSD (gp2)**.
     * Verifica que el tamaño diga **`20`** GiB.
   * **Connectivity (Conectividad - EL PASO DONDE EL 90% SE EQUIVOCA):**
     * Baja hasta **Public access** (Acceso público) y cámbialo a **`Yes`** (Sí). *(Trampa de AWS: Aunque la base de datos original tenía acceso público en "Yes", cuando restauras un Snapshot, AWS lo regresa a "No" por defecto. Debes ponerlo en **Yes** para poder conectarte en el último paso).*
     * En **VPC security group (firewall)**: Deja marcado **Choose existing** (Elegir existente).
     * Verás que está puesto el grupo `default`. Quítalo haciendo clic en la **`X`** de la cajita `default`, abre la lista desplegable y selecciona el grupo que creaste al inicio: **`rds-public-sg`**.

4. Baja hasta el final de la página y haz clic en el botón naranja **Restore DB instance**.
5. AWS te llevará de vuelta a **Databases**. Ahora verás **DOS** bases de datos en la lista:
   * `mysql-origen` (Available)
   * `mysql-restaurada` (Creating...)
6. **Espera final:** Espera unos **5 a 7 minutos** hasta que `mysql-restaurada` termine de crearse y su estado diga **`Available`** en verde. *(No pases a la Etapa 7 hasta que diga Available).*

---

### ETAPA 7: Conectarse a la Base de Datos Restaurada y Validar `(Flujo 6: Conexión Final)`

Vamos a comprobar que nuestro segundo servidor (`mysql-restaurada`) funciona y tiene la tabla de clientes que guardamos en el Snapshot.

1. Cuando `mysql-restaurada` ya diga **`Available`**, haz clic sobre su nombre azul **`mysql-restaurada`**.
2. En la pestaña **Connectivity & security**, copia su **Endpoint** (fíjate que es una dirección nueva que empieza por `mysql-restaurada...`).
3. Regresa a **MySQL Workbench** en tu computadora.
4. Haz clic en la pestaña de inicio (**Home**) arriba a la izquierda y dale otra vez al botón **`+`** junto a *MySQL Connections* para crear una segunda conexión:
   * **Connection Name:** `2 - Base de Datos Restaurada (Backup)`
   * **Hostname:** Pega aquí el **nuevo Endpoint** de `mysql-restaurada`.
   * **Port:** `3306`
   * **Username:** `admin` *(es el mismo usuario que tenía la original)*.
   * **Password:** Haz clic en **Store in Vault...** y pon la misma contraseña **`Admin12345!`**
5. Haz clic en **Test Connection** -> **OK** -> **OK**, y entra haciendo doble clic en `2 - Base de Datos Restaurada (Backup)`.
6. Ejecuta esta consulta con el icono del **Rayo** en la barra superior del editor:

```sql
-- 1. Verificar que la base de datos "empresa_xyz" está en el nuevo servidor
SHOW DATABASES;

-- 2. Comprobar que Ana y Carlos se recuperaron perfectamente desde el Snapshot
USE empresa_xyz;
SELECT * FROM clientes;
```

Verás que la tabla `clientes` y sus registros están intactos en este servidor completamente nuevo.

---

## 4. Lista de Verificación Final y Entrega del Reto

Antes de finalizar tu práctica o presionar el botón de evaluación en tu entorno de laboratorio, revisa que tengas estos 4 puntos cumplidos en tu consola de AWS:

- [x] **Región:** Todo fue creado en `us-east-1` (N. Virginia).
- [x] **Instancia 1 (`mysql-origen`):** Estado `Available`, Single-AZ, `20 GiB`, acceso público `Yes`, usando el Security Group con puerto `3306` abierto a `0.0.0.0/0`.
- [x] **Snapshot (`xyz-snapshot-backup`):** Estado `Available` en la sección *Snapshots*.
- [x] **Instancia 2 (`mysql-restaurada`):** Estado `Available`, Single-AZ, clase `db.t3.micro`, almacenamiento `gp2` de `20 GiB`, acceso público `Yes` y usando el mismo Security Group.

### ¿Cómo enviar y cerrar el reto?
1. Regresa a la pestaña del navegador donde se encuentra el panel de control de tu laboratorio.
2. Si tu entorno cuenta con validación automática, haz clic en el botón **Validate** (Validar) y verifica que el estado cambie a **Success**.
3. En la consola de AWS, haz clic arriba a la derecha en tu nombre de usuario -> **Sign out** (Cerrar sesión).
4. Finalmente, en el panel del laboratorio, haz clic en el botón **End Lab / End Challenge** para finalizar la sesión y apagar los recursos. Reto superado.
