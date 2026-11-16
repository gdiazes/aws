# Laboratorio: Creación de Usuarios y Grupos de AWS IAM con Terraform

* **Nivel:** Fundamental
* **Duración estimada:** 30 minutos
* **Herramientas y servicios:** Terraform CLI, Visual Studio Code, AWS CLI, AWS IAM
* **Región de AWS:** `us-east-1` *(referencia del proveedor; IAM es un servicio global)*

---

## 1. Descripción General y Objetivos

En este laboratorio aprenderás a automatizar el aprovisionamiento de identidades en **AWS Identity and Access Management (IAM)** utilizando **Terraform** como herramienta de Infraestructura como Código (IaC).

Al finalizar este laboratorio, serás capaz de:
1. Configurar un proyecto estructurado de Terraform en Visual Studio Code (`main.tf`, `variables.tf`, `terraform.tfvars`, `outputs.tf`).
2. Autenticar Terraform de forma segura con AWS sin incrustar credenciales en el código.
3. Definir y aprovisionar usuarios, etiquetas (*Tags*), grupos y membresías de IAM en HCL.
4. Validar los recursos creados mediante Terraform, AWS CLI y la Consola de AWS, y destruirlos limpiamente al finalizar.

---

## 2. Conceptos Clave

* **Terraform (IaC):** Herramienta de Infraestructura como Código desarrollada por HashiCorp (licencia BSL 1.1 en versiones 1.6+) que permite definir, versionar y aprovisionar recursos en la nube de forma declarativa mediante **HCL (HashiCorp Configuration Language)** o JSON.
* **Comandos fundamentales de Terraform:**
  * `terraform init`: Inicializa el directorio de trabajo y descarga los plugins del proveedor (`hashicorp/aws`).
  * `terraform plan`: Genera un plan de ejecución mostrando qué se creará, modificará o destruirá sin aplicar cambios reales.
  * `terraform apply`: Aplica los cambios declarados en la infraestructura y actualiza el archivo de estado (`terraform.tfstate`).
  * `terraform destroy`: Elimina de forma controlada todos los recursos gestionados por el estado actual.
* **`aws_iam_user_group_membership` vs. `aws_iam_group_membership`:** En Terraform, `aws_iam_group_membership` gestiona de forma *exclusiva* todos los miembros de un grupo (pudiendo sobrescribir miembros añadidos fuera del código). Para evitar conflictos, se recomienda **`aws_iam_user_group_membership`**, que asocia grupos por usuario de forma aditiva y segura.

---

## 3. Diagrama de Arquitectura

```text
+-------------------------------------------------------------------+
|  Equipo Local (VS Code + Terraform CLI + AWS CLI autenticado)     |
|  Archivos: main.tf | variables.tf | terraform.tfvars | outputs.tf |
+---------------------------------+---------------------------------+
                                  |
                     terraform init / plan / apply
                                  |
                                  v
+-------------------------------------------------------------------+
|                        Cuenta de AWS (IAM)                        |
|                                                                   |
|   +--------+   +---------+                 +------------------+   |
|   |  John  |   |  Sarah  | --------------> |  Grupo: DevTeam  |   |
|   +--------+   +---------+                 +------------------+   |
|                                                                   |
|   +--------+   +---------+                 +------------------+   |
|   |  Rita  |   |   Ted   | --------------> |  Grupo: HRTeam   |   |
|   +--------+   +---------+                 +------------------+   |
+-------------------------------------------------------------------+
```

---

## 4. Prerrequisitos

Instala previamente las siguientes herramientas en tu equipo local:
1. **Terraform CLI:** Descarga e instala la versión estable desde la guía oficial: `https://developer.hashicorp.com/terraform/install`
2. **AWS CLI v2:** Necesario para autenticar tus credenciales de forma segura sin guardarlas en archivos de Terraform: `https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html`
3. **Visual Studio Code:** `https://code.visualstudio.com/download` *(se recomienda instalar la extensión oficial **HashiCorp Terraform**)*.
4. **Cuenta de AWS** con permisos administrativos sobre **IAM**.

---

## 5. Instrucciones Paso a Paso

### Tarea 1: Configurar las Credenciales de AWS de Forma Segura

Por buenas prácticas de seguridad, **nunca escribas `access_key` ni `secret_key` dentro de archivos `.tf` o `.tfvars`**. En su lugar, configura un perfil local con AWS CLI.

1. Si ya tienes configuradas tus credenciales en AWS CLI (o acceso vía AWS IAM Identity Center / `aws sso login`), pasa directamente al paso 4 para verificarlas.
2. Si necesitas generar credenciales programáticas temporales para este laboratorio:
   * Inicia sesión en la **AWS Management Console** y ve a **IAM → Users**.
   * Selecciona tu usuario IAM administrativo, abre la pestaña **Security credentials** y haz clic en **`Create access key`**.
   * Elige **`Command Line Interface (CLI)`**, confirma la recomendación, haz clic en **`Create access key`** y anota tu **Access key** y **Secret access key**. *(Recuerda eliminar esta clave al finalizar el laboratorio en la Tarea 9).*
3. Abre una terminal en tu equipo y ejecuta:
   ```bash
   aws configure
   ```
   Ingresa los datos solicitados:
   * **AWS Access Key ID:** `<TU_ACCESS_KEY>`
   * **AWS Secret Access Key:** `<TU_SECRET_KEY>`
   * **Default region name:** `us-east-1`
   * **Default output format:** `json`
4. Verifica que tu sesión funcione correctamente ejecutando:
   ```bash
   aws sts get-caller-identity
   ```

---

### Tarea 2: Preparar el Espacio de Trabajo en Visual Studio Code

1. Abre **Visual Studio Code**.
2. Abre la terminal integrada desde el menú superior: **Terminal → New Terminal** (o **View → Terminal**).
3. Crea una carpeta de trabajo limpia en tu directorio de usuario y accede a ella:
   ```bash
   mkdir terraform-iam-lab
   cd terraform-iam-lab
   ```
4. Verifica que **Terraform** esté correctamente instalado:
   ```bash
   terraform version
   ```
   *(Si obtienes un error de comando no encontrado, revisa la instalación de los Prerrequisitos y reinicia VS Code para actualizar la variable `PATH`).*
5. Abre esa carpeta en VS Code ejecutando en la misma terminal:
   ```bash
   code .
   ```
   *(O usando **File → Open Folder...** y seleccionando `terraform-iam-lab`).*

---

### Tarea 3: Crear el Archivo de Variables (`variables.tf` y `terraform.tfvars`)

1. En el panel **Explorer** de VS Code, haz clic en **New File** y crea el archivo **`variables.tf`**.
2. Pega el siguiente contenido y guarda con `Ctrl + S` (`Cmd + S` en macOS):

```hcl
variable "aws_region" {
  description = "Región de AWS utilizada por el proveedor"
  type        = string
  default     = "us-east-1"
}
```

3. Crea un segundo archivo llamado **`terraform.tfvars`** en la misma carpeta, pega el siguiente contenido y guarda:

```hcl
aws_region = "us-east-1"
```

> *Nota:* Si trabajas con múltiples cuentas o entornos, aquí es donde normalmente parametrizarías nombres de entorno, etiquetas comunes o regiones, manteniendo los secretos fuera del código.

---

### Tarea 4: Configurar el Proveedor y los Usuarios IAM (`main.tf`)

1. Crea un nuevo archivo llamado **`main.tf`** dentro de `terraform-iam-lab`.
2. Agrega el bloque `terraform` (fijando la versión del proveedor de AWS) y el bloque `provider "aws"`, seguido de la definición de los 4 usuarios de IAM:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#################### Creación de 4 Usuarios IAM ####################

resource "aws_iam_user" "user1" {
  name = "John"
  path = "/"

  tags = {
    Team = "Dev-Team"
  }
}

resource "aws_iam_user" "user2" {
  name = "Sarah"
  path = "/"

  tags = {
    Team = "Dev-Team"
  }
}

resource "aws_iam_user" "user3" {
  name = "Rita"
  path = "/"

  tags = {
    Team = "HR-Team"
  }
}

resource "aws_iam_user" "user4" {
  name = "Ted"
  path = "/"

  tags = {
    Team = "HR-Team"
  }
}
```

---

### Tarea 5: Agregar Grupos de IAM y Membresías en `main.tf`

1. Al final del mismo archivo **`main.tf`**, añade los bloques para crear los dos grupos (`DevTeam` y `HRTeam`) y asociar los usuarios mediante `aws_iam_user_group_membership`:

```hcl
#################### Creación de Grupos IAM y Membresías ####################

resource "aws_iam_group" "dev_team" {
  name = "DevTeam"
}

resource "aws_iam_group" "hr_team" {
  name = "HRTeam"
}

resource "aws_iam_user_group_membership" "john_dev" {
  user   = aws_iam_user.user1.name
  groups = [aws_iam_group.dev_team.name]
}

resource "aws_iam_user_group_membership" "sarah_dev" {
  user   = aws_iam_user.user2.name
  groups = [aws_iam_group.dev_team.name]
}

resource "aws_iam_user_group_membership" "rita_hr" {
  user   = aws_iam_user.user3.name
  groups = [aws_iam_group.hr_team.name]
}

resource "aws_iam_user_group_membership" "ted_hr" {
  user   = aws_iam_user.user4.name
  groups = [aws_iam_group.hr_team.name]
}
```

2. Guarda el archivo **`main.tf`** presionando `Ctrl + S` (`Cmd + S` en macOS).

---

### Tarea 6: Crear el Archivo de Salidas (`outputs.tf`)

1. Crea un nuevo archivo llamado **`outputs.tf`** en la carpeta `terraform-iam-lab`.
2. Pega el siguiente contenido para mostrar los **ARNs** de los usuarios y grupos creados al finalizar el despliegue, y guarda el archivo:

```hcl
output "user1_arn" {
  description = "ARN del usuario John"
  value       = aws_iam_user.user1.arn
}

output "user2_arn" {
  description = "ARN del usuario Sarah"
  value       = aws_iam_user.user2.arn
}

output "user3_arn" {
  description = "ARN del usuario Rita"
  value       = aws_iam_user.user3.arn
}

output "user4_arn" {
  description = "ARN del usuario Ted"
  value       = aws_iam_user.user4.arn
}

output "dev_team_group_arn" {
  description = "ARN del grupo DevTeam"
  value       = aws_iam_group.dev_team.arn
}

output "hr_team_group_arn" {
  description = "ARN del grupo HRTeam"
  value       = aws_iam_group.hr_team.arn
}
```

---

### Tarea 7: Inicializar, Planificar y Aplicar la Configuración de Terraform

En la terminal integrada de VS Code (asegurándote de estar dentro de `terraform-iam-lab`):

1. **Formatea y valida la sintaxis** de tus archivos HCL:
   ```bash
   terraform fmt
   terraform validate
   ```
   Deberías ver `Success! The configuration is valid.`

2. **Inicializa Terraform** para descargar el proveedor `hashicorp/aws`:
   ```bash
   terraform init
   ```
   Verás el mensaje `Terraform has been successfully initialized!` y se creará el archivo de bloqueo `.terraform.lock.hcl`.

3. **Genera el plan de ejecución:**
   ```bash
   terraform plan
   ```
   Revisa la salida: debe indicar **`Plan: 10 to add, 0 to change, 0 to destroy`** (4 usuarios + 2 grupos + 4 membresías).

4. **Aplica la configuración:**
   ```bash
   terraform apply
   ```
   Cuando Terraform solicite confirmación (`Enter a value:`), escribe **`yes`** y presiona `Enter`.

5. Al completar, verás **`Apply complete! Resources: 10 added, 0 changed, 0 destroyed.`** seguido de la sección **`Outputs:`** con los 6 ARNs definidos en `outputs.tf`.

---

### Tarea 8: Validación del Laboratorio (Consola AWS y CLI)

#### Validación 1: Desde Terraform y AWS CLI
1. Ejecuta en tu terminal los siguientes comandos para inspeccionar el estado y verificar directamente contra la API de AWS:
   ```bash
   terraform state list
   terraform output
   aws iam get-group --group-name DevTeam --query "Users[].UserName"
   aws iam get-group --group-name HRTeam --query "Users[].UserName"
   ```
   * `DevTeam` debe devolver `["John", "Sarah"]`.
   * `HRTeam` debe devolver `["Rita", "Ted"]`.

#### Validación 2: Desde la Consola de Administración de AWS
1. Abre la **AWS Management Console** y navega al servicio **IAM**.
2. En el menú izquierdo, haz clic en **`Users`**: verifica que aparezcan `John`, `Sarah`, `Rita` y `Ted`.
3. Haz clic en **`User groups`**:
   * Verifica que aparezcan `DevTeam` y `HRTeam`, ambos con **`2`** usuarios asignados.
   * *(Nota: En la columna Permissions aparecerá "Not defined" porque en este laboratorio únicamente se crean los usuarios, grupos y membresías; el adjunto de políticas se gestiona con recursos `aws_iam_group_policy_attachment`).*
4. Haz clic en **`DevTeam`** y confirma que contiene a **`John`** y **`Sarah`**.
5. Haz clic en **`HRTeam`** y confirma que contiene a **`Rita`** y **`Ted`**.

---

### Tarea 9: Limpieza de Recursos (Obligatoria)

1. En la terminal de VS Code dentro de `terraform-iam-lab`, ejecuta:
   ```bash
   terraform destroy
   ```
2. Escribe **`yes`** cuando te pida confirmación. Al finalizar, verás **`Destroy complete! Resources: 10 destroyed.`**
3. **Limpieza de credenciales (si creaste un Access Key en la Tarea 1):**
   * Regresa a la consola de **IAM → Users → `<tu-usuario>` → Security credentials**.
   * Localiza el Access Key creado para este laboratorio, selecciona **Actions → Deactivate** y luego **Delete**.
4. Cierra tu sesión en la Consola de AWS.

---

## 6. Dato Complementario: Versionado y Estado Remoto en Producción

Al gestionar IAM mediante Terraform en equipos de trabajo reales, se recomienda almacenar el archivo de estado (`terraform.tfstate`) en un **backend remoto seguro** (como un bucket de **Amazon S3** con cifrado habilitado y bloqueo de estado) en lugar de mantenerlo localmente, e integrar el código en un repositorio Git protegido (excluyendo archivos locales como `.terraform/` y `*.tfstate` mediante `.gitignore`).

---

## 7. Conclusión

En este laboratorio:
* Configuraste un entorno seguro de Terraform y Visual Studio Code autenticado mediante AWS CLI.
* Definiste variables, recursos y salidas en sintaxis HCL moderna fijando la versión del proveedor de AWS.
* Aprovisionaste 4 usuarios de IAM, 2 grupos y sus membresías de forma automatizada e idempotente.
* Validaste los recursos tanto por línea de comandos como en la consola visual y ejecutaste la destrucción completa de la infraestructura.
