# Laboratorio: Acceso Seguro a Amazon S3 desde EC2 mediante AWS IAM Roles

* **Nivel:** Intermedio (Associate)
* **Duración estimada:** 30 minutos
* **Servicios principales:** AWS IAM, Amazon EC2, Amazon S3
* **Región de AWS recomendada:** `us-east-1` (EE. UU. Este - Norte de Virginia)

---

## 1. Descripción General y Objetivos

En este laboratorio aprenderás cómo permitir que una instancia **Amazon EC2** interactúe con un bucket de **Amazon S3** utilizando un **IAM Role (Instance Profile)**, evitando almacenar claves de acceso permanentes (`Access Key` / `Secret Key`) dentro del servidor.

Al finalizar este laboratorio, serás capaz de:
1. Crear un bucket privado en Amazon S3.
2. Crear una política personalizada de IAM (*Customer Managed Policy*) aplicando el principio de mínimo privilegio.
3. Crear un **IAM Role** para Amazon EC2 y adjuntarle permisos de acceso a S3.
4. Lanzar una instancia EC2 asociando el rol mediante su *Instance Profile*.
5. Conectarte a la instancia y manipular objetos en S3 usando **AWS CLI** con credenciales temporales.

---

## 2. Conceptos Clave

* **Política Basada en Identidad (*Identity-Based Policy*):** Documento JSON adjunto a una identidad (usuario, grupo o rol de IAM) que define qué acciones puede ejecutar dicha identidad sobre qué recursos. Se dividen en:
  * **AWS Managed Policies:** Creadas y mantenidas por AWS (ej. `AmazonS3ReadOnlyAccess`, `AmazonS3FullAccess`).
  * **Customer Managed Policies:** Creadas y administradas por ti en tu cuenta para lograr un control granular de mínimo privilegio.
* **Política Basada en Recursos (*Resource-Based Policy*):** Documento JSON adjunto directamente a un recurso (como una *Bucket Policy* en S3, una *Queue Policy* en SQS o una *Trust Policy* en un IAM Role) que define quién tiene permiso para acceder a ese recurso.
* **IAM Role (Rol de IAM):** Identidad de AWS con permisos específicos que puede ser asumida por entidades de confianza (como el servicio EC2). No utiliza credenciales permanentes; en su lugar, emite **credenciales de seguridad temporales** mediante AWS STS y el servicio de metadatos de la instancia (**IMDSv2**).
* **Amazon S3 (Simple Storage Service):** Servicio de almacenamiento de objetos con capacidad virtualmente ilimitada (hasta **50 TB** por objeto individual y carga única `PUT` de hasta 5 GB), diseñado para **99.999999999 % (11 nueves) de durabilidad** y **99.99 % de disponibilidad** en la clase S3 Standard. Aunque los nombres de los buckets deben ser globalmente únicos, **cada bucket es un recurso regional**.

---

## 3. Diagrama de Arquitectura

```text
+-----------------------------------------------------------------------+
|                       Cuenta de AWS (us-east-1)                       |
|                                                                       |
|  +-----------------------------+      Asume rol      +-------------+  |
|  |  Instancia Amazon EC2       | ------------------> |  IAM Role   |  |
|  |  (Amazon Linux 2023)        |    (Vía IMDSv2 /    |  EC2S3Role  |  |
|  |  - Key Pair: S3EC2LabKey    |     Credenciales    +------+------+  |
|  |  - AWS CLI integrado        |     temporales)            |         |
|  +--------------+--------------+                            |         |
|                 |                                           |         |
|                 | aws s3 ls / aws s3 mv                     | Política|
|                 v                                           v         |
|  +-----------------------------------------------------------------+  |
|  |                  Amazon S3 Bucket (Privado)                     |  |
|  |                  s3-ec2-role-lab-<sufijo-unico>                 |  |
|  |                  Objetos: test.txt, new.txt, smile.txt          |  |
|  +-----------------------------------------------------------------+  |
+-----------------------------------------------------------------------+
```

---

## 4. Prerrequisitos

* Acceso a la Consola de Administración de AWS con permisos para gestionar **S3**, **IAM** y **EC2**.
* Cliente SSH en tu equipo local (Terminal en Linux/macOS, PowerShell/Git Bash en Windows) o uso directo de **EC2 Instance Connect** desde el navegador.

---

## 5. Instrucciones Paso a Paso

### Tarea 1: Iniciar sesión y seleccionar la región

1. Inicia sesión en la **AWS Management Console**.
2. En la esquina superior derecha, asegúrate de seleccionar la región **`US East (N. Virginia) us-east-1`**.

---

### Tarea 2: Crear el Bucket en Amazon S3

Crearemos primero el bucket para poder referenciar su ARN exacto en la política de mínimo privilegio.

1. En la barra de búsqueda superior, escribe **`S3`** y abre el servicio **S3**.
2. Haz clic en **`Create bucket`**.
3. Configura los siguientes parámetros:
   * **Bucket type:** `General purpose`.
   * **Bucket name:** Ingresa un nombre único a nivel global (solo minúsculas, números y guiones), por ejemplo: `s3-ec2-role-lab-<tus-iniciales>-<4-digitos>` (ejemplo: `s3-ec2-role-lab-jp-4821`).
   * **Object Ownership:** Deja **`ACLs disabled (recommended)`**.
   * **Block Public Access settings for this bucket:** Mantén marcada la casilla **`Block all public access`**.
4. Deja el resto de opciones por defecto y haz clic en **`Create bucket`**.
5. **Anota el nombre exacto de tu bucket**, ya que lo usarás en las tareas siguientes.

---

### Tarea 3: Crear la Política Personalizada y el IAM Role para EC2

#### Parte A: Crear la política de mínimo privilegio

1. En la barra de búsqueda superior, escribe **`IAM`** y abre el servicio **IAM**.
2. En el menú izquierdo, selecciona **`Policies`** y haz clic en **`Create policy`**.
3. Cambia a la pestaña **`JSON`** en el editor de políticas y pega el siguiente documento, **reemplazando `TU-NOMBRE-DE-BUCKET`** por el nombre del bucket que creaste en la Tarea 2:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowListAllBuckets",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        },
        {
            "Sid": "AllowReadWriteSpecificBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::TU-NOMBRE-DE-BUCKET",
                "arn:aws:s3:::TU-NOMBRE-DE-BUCKET/*"
            ]
        }
    ]
}
```
> *Nota:* Esta política permite listar los buckets (`ListAllMyBuckets`), listar el contenido de tu bucket (`ListBucket`), leer objetos (`GetObject`) y subir objetos (`PutObject`), bloqueando acciones destructivas como borrar el bucket o modificar otros buckets. *(Si en un entorno de prueba prefieres usar una política administrada amplia, puedes omitir la Parte A y seleccionar `AmazonS3FullAccess` en la Parte B, aunque no se recomienda en producción).*

4. Haz clic en **`Next`**.
5. En **Policy name**, escribe: **`EC2S3LabBucketPolicy`**.
6. Haz clic en **`Create policy`**.

#### Parte B: Crear el IAM Role para EC2

7. En el menú izquierdo de IAM, selecciona **`Roles`** y haz clic en **`Create role`**.
8. En **Trusted entity type**, selecciona **`AWS service`**.
9. En **Service or use case**, selecciona **`EC2`** y confirma el caso de uso **`EC2` (*Allows EC2 instances to call AWS services on your behalf*)**. Haz clic en **`Next`**.
10. En **Permissions policies**, busca y marca la casilla de **`EC2S3LabBucketPolicy`** (la política que creaste en el paso anterior). Haz clic en **`Next`**.
11. En **Role name**, escribe: **`EC2S3Role`**.
12. Revisa que la *Trust policy* tenga como entidad principal `"Service": "ec2.amazonaws.com"` y haz clic en **`Create role`**.

---

### Tarea 4: Lanzar la Instancia EC2 con el IAM Role Adjunto

1. Verifica que sigues en la región **`us-east-1`**. En el buscador superior, escribe **`EC2`** y abre el servicio **EC2**.
2. En el panel izquierdo, selecciona **`Instances`** y haz clic en **`Launch instances`**.
3. Configura los parámetros de la instancia:
   * **Name:** `S3EC2Server`
   * **Application and OS Images (AMI):** Selecciona **`Amazon Linux 2023 AMI`** (arquitectura `64-bit (x86)`, marcada como *Free tier eligible*).
   * **Instance type:** Selecciona **`t3.micro`** (o `t2.micro` si tu cuenta aplica al esquema anterior de Free Tier).
   * **Key pair (login):** Haz clic en **`Create new key pair`**:
     * **Key pair name:** `S3EC2LabKey`
     * **Key pair type:** `RSA`
     * **Private key file format:** `.pem` *(o `.ppk` si usarás PuTTY en Windows)*.
     * Haz clic en **`Create key pair`** y guarda el archivo descargado (`S3EC2LabKey.pem`) en una carpeta segura.
4. En **Network settings**, haz clic en **`Edit`**:
   * **Auto-assign public IP:** **`Enable`**.
   * **Firewall (security groups):** Selecciona **`Create security group`**:
     * **Security group name:** `S3EC2Server-SG`
     * **Description:** `Allow SSH access from my IP`
     * **Inbound Security Group Rules:** Tipo **`SSH`** (Puerto `22`), **Source type:** selecciona **`My IP`** *(por seguridad, evita dejar `Anywhere 0.0.0.0/0`. Si te conectas mediante **EC2 Instance Connect** desde el navegador, permite temporalmente `My IP` o el rango de EC2 Instance Connect de `us-east-1`)*.
5. Despliega la sección **`Advanced details`** al final de la página:
   * En **IAM instance profile**, selecciona **`EC2S3Role`** (el rol creado en la Tarea 3).
   * Verifica que en **Metadata version** esté seleccionado **`V2 only (token required)`** (predeterminado en Amazon Linux 2023).
6. Deja el resto de opciones por defecto y haz clic en **`Launch instance`**.
7. Haz clic en **`View all instances`** y espera 1–2 minutos hasta que el estado sea **`Running`** y los *Status checks* muestren **`2/2 checks passed`**.
8. Selecciona la instancia `S3EC2Server` y copia su **Public IPv4 address**.

---

### Tarea 5: Acceder al Bucket S3 desde la Instancia EC2 vía AWS CLI

#### Paso 1: Conectarse a la instancia EC2
Elige una de las dos opciones siguientes:

* **Opción A — Desde tu terminal local (SSH):**
  ```bash
  # En Linux / macOS / Git Bash, ajusta los permisos de la llave privada:
  chmod 400 S3EC2LabKey.pem

  # Conéctate usando la IP pública de tu instancia:
  ssh -i S3EC2LabKey.pem ec2-user@<TU_IP_PUBLICA>
  ```
* **Opción B — Desde el navegador (EC2 Instance Connect):**
  En la consola de EC2, selecciona `S3EC2Server`, haz clic en **`Connect`**, elige la pestaña **`EC2 Instance Connect`** (usuario `ec2-user`) y presiona **`Connect`**.

#### Paso 2: Validar la identidad asumida por la instancia
1. Una vez dentro de la terminal de la instancia (como `ec2-user`, sin necesidad de usar `sudo su`), verifica qué identidad está usando el AWS CLI:
   ```bash
   aws sts get-caller-identity
   ```
   Deberías ver un `Arn` similar a: `arn:aws:sts::<ACCOUNT_ID>:assumed-role/EC2S3Role/i-<INSTANCE_ID>`. Esto confirma que la instancia obtuvo credenciales temporales gracias al **IAM Role**.

#### Paso 3: Listar y subir archivos al bucket S3
2. Lista los buckets de la cuenta:
   ```bash
   aws s3 ls
   ```
   Verás listado el bucket que creaste en la Tarea 2.

3. Crea un archivo de prueba y muévelo al bucket S3 (reemplaza `<TU_BUCKET>` por el nombre real de tu bucket):
   ```bash
   touch test.txt
   aws s3 mv test.txt s3://<TU_BUCKET>/
   ```
4. Crea dos archivos adicionales y súbelos al bucket (uno con `mv` y otro con `cp` para ver la diferencia):
   ```bash
   echo "Hola desde EC2 con IAM Role" > new.txt
   touch smile.txt
   aws s3 mv new.txt s3://<TU_BUCKET>/
   aws s3 cp smile.txt s3://<TU_BUCKET>/
   ```
5. Lista los objetos dentro de tu bucket desde la terminal de EC2:
   ```bash
   aws s3 ls s3://<TU_BUCKET>/
   ```
   Deberías ver los tres archivos: `new.txt`, `smile.txt` y `test.txt`.

---

### Tarea 6: Validación del Laboratorio

Realiza las siguientes comprobaciones en la Consola de AWS para confirmar que todo funciona según lo esperado:

1. **Verificación de objetos en S3:**
   * Ve a **S3 → Buckets → `<TU_BUCKET>`**.
   * En la pestaña **Objects**, confirma que aparecen `test.txt`, `new.txt` y `smile.txt`.
2. **Prueba negativa de mínimo privilegio (Opcional recomendado):**
   * Desde la terminal de tu EC2, intenta eliminar un objeto del bucket:
     ```bash
     aws s3 rm s3://<TU_BUCKET>/test.txt
     ```
   * El comando **debe devolver `AccessDenied`**, demostrando que tu política personalizada `EC2S3LabBucketPolicy` aplica el principio de mínimo privilegio (permite leer y escribir, pero no eliminar).
3. **Verificación de credenciales:**
   * Ejecuta `ls -la ~/.aws` en tu EC2 y confirma que **no existe** ningún archivo `~/.aws/credentials` con claves estáticas guardadas.

---

### Tarea 7: Limpieza de Recursos (Obligatoria en cuentas propias)

Para evitar cargos innecesarios en tu cuenta de AWS, elimina todos los recursos creados en el siguiente orden:

1. **Terminar la instancia EC2:**
   * Ve a **EC2 → Instances**, selecciona `S3EC2Server` → **Instance state → Terminate (delete) instance**.
   * Espera a que el estado cambie a **`Terminated`**.
2. **Eliminar el Security Group y el Key Pair:**
   * En **EC2 → Security Groups**, elimina `S3EC2Server-SG` (solo disponible una vez terminada la instancia).
   * En **EC2 → Key Pairs**, elimina `S3EC2LabKey`.
3. **Vaciar y eliminar el bucket S3:**
   * Ve a **S3 → Buckets**, selecciona tu bucket y haz clic en **`Empty`** (confirma escribiendo `permanently delete`).
   * Regresa a la lista de buckets, selecciona el bucket vacío y haz clic en **`Delete`**.
4. **Eliminar el IAM Role y la Política:**
   * Ve a **IAM → Roles**, busca `EC2S3Role` y haz clic en **`Delete`**.
   * Ve a **IAM → Policies**, filtra por *Customer managed*, selecciona `EC2S3LabBucketPolicy` → **Actions → Delete**.
5. Cierra tu sesión en la Consola de AWS.

---

## 6. Dato Complementario: IAM Access Analyzer para S3

En entornos productivos, puedes habilitar **IAM Access Analyzer** para auditar continuamente tus buckets de S3 y tus roles de IAM. Access Analyzer detecta automáticamente si un bucket es accesible públicamente o compartido con cuentas externas mediante políticas de bucket o ACLs, y genera recomendaciones para corregir configuraciones inseguras.

---

## 7. Conclusión

En este laboratorio:
* Creaste un bucket privado en Amazon S3.
* Diseñaste una política personalizada (*Customer Managed Policy*) con principio de mínimo privilegio y la asociaste a un **IAM Role** para EC2.
* Conectaste el rol a una instancia **Amazon Linux 2023** mediante un *Instance Profile*.
* Ejecutaste operaciones en S3 desde **AWS CLI** utilizando credenciales temporales emitidas automáticamente por AWS STS vía IMDSv2, sin exponer claves estáticas.
