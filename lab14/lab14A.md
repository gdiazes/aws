# Laboratorio: Introducción a AWS Identity and Access Management (IAM)

* **Nivel:** Fundamental
* **Duración estimada:** 30 minutos
* **Servicio principal:** AWS Identity and Access Management (IAM)
* **Ámbito / Región de AWS:** Global (IAM es un servicio global de AWS)

---

## 1. Descripción General y Objetivos

Este laboratorio cubre los fundamentos de **AWS Identity and Access Management (IAM)**, el servicio que permite controlar de forma segura quién está autenticado y autorizado para acceder a los recursos de una cuenta de AWS.

Al finalizar este laboratorio, serás capaz de:
1. Navegar por la consola de AWS IAM.
2. Crear usuarios de IAM con acceso a la consola de administración y etiquetas (*Tags*).
3. Crear grupos de IAM y asignarles políticas administradas (*AWS Managed Policies*).
4. Validar los permisos efectivos de los usuarios aplicando buenas prácticas de seguridad.

---

## 2. Conceptos Clave

* **IAM (Identity and Access Management):** Servicio web de AWS que gestiona el acceso de identidades a servicios y recursos de AWS sin necesidad de compartir las credenciales del usuario raíz (*Root User*).
* **Usuario Raíz (*Root User*):** La primera identidad creada al abrir una cuenta de AWS. Tiene acceso irrestricto a todos los recursos y configuraciones de facturación; por seguridad, no debe usarse para tareas cotidianas.
* **IAM Users (Usuarios):** Identidades con credenciales de largo plazo (contraseña de consola y/o claves de acceso) asignadas a personas o aplicaciones específicas dentro de una cuenta.
* **IAM User Groups (Grupos):** Colecciones de usuarios de IAM que permiten asignar permisos de manera colectiva y ordenada.
* **IAM Policies (Políticas):** Documentos en formato JSON que definen qué acciones están permitidas o denegadas sobre qué recursos y bajo qué condiciones.
* **IAM Roles (Roles):** Identidades pensadas para ser asumidas por entidades de confianza (usuarios, servicios de AWS o cuentas externas) mediante políticas de confianza. A diferencia de los usuarios, los roles no poseen credenciales estáticas permanentes, sino que emiten **credenciales temporales** a través de AWS STS.

> **Nota arquitectónica y de buenas prácticas:** Para entornos productivos con múltiples usuarios humanos, AWS recomienda gestionar el acceso centralizado mediante **AWS IAM Identity Center**. En este laboratorio se crean usuarios IAM nativos con fines formativos.

---

## 3. Diagrama de Arquitectura

```text
+-------------------+       +----------------------------------+       +---------------------------+
|                   |       |             AWS IAM              |       |     Servicios de AWS      |
|  Usuarios IAM     |       |                                  |       |                           |
|  - John           | ----> |  Grupo: Dev-Team                 | ----> |  Amazon EC2 (Solo lectura)|
|  - Sarah          |       |  (EC2 & S3 ReadOnly Policies)    |       |  Amazon S3  (Solo lectura)|
+-------------------+       +----------------------------------+       +---------------------------+
|                   |       |                                  |       |                           |
|  Usuarios IAM     |       |  Grupo: HR-Team                  | ----> |  AWS Billing & Cost Mgmt  |
|  - Ted            | ----> |  (Billing / BillingReadOnly)     |       |  (Facturación)            |
|  - Rita           |       +----------------------------------+       +---------------------------+
```

---

## 4. Prerrequisitos

* Acceso a una cuenta de AWS (entorno de laboratorio o cuenta propia) con un usuario o rol que posea permisos administrativos sobre IAM (por ejemplo, `iam:CreateUser`, `iam:CreateLoginProfile`, `iam:TagUser`, `iam:CreateGroup`, `iam:AddUserToGroup`, `iam:AttachGroupPolicy`).
* Navegador web moderno.

---

## 5. Instrucciones Paso a Paso

### Tarea 1: Iniciar sesión en la Consola de Administración de AWS

1. Inicia sesión en la **AWS Management Console** utilizando las credenciales administrativas asignadas a tu entorno de práctica.
2. Verifica en la barra superior derecha que la sesión esté activa.
3. En la barra de búsqueda superior de AWS, escribe **`IAM`** y selecciona **IAM** (bajo la categoría *Security, Identity, & Compliance*).
   > *Nota:* Notarás que en la esquina superior derecha el selector de región cambia automáticamente a **`Global`**, ya que IAM no depende de una región específica.

---

### Tarea 2: Crear Usuarios de IAM

En esta tarea crearás 4 usuarios de IAM sin adjuntarles permisos directamente (los permisos se heredarán posteriormente a través de grupos).

#### Parte A: Crear los usuarios del equipo de Desarrollo (`John` y `Sarah`)

1. En el panel de navegación izquierdo de IAM, selecciona **`Users`** y haz clic en el botón **`Create user`**.
2. En la pantalla **Specify user details**:
   * **User name:** Escribe `John`.
   * Marca la casilla **`Provide user access to the AWS Management Console - optional`**.
   * Si se despliega la pregunta *"Are you providing access to a person?"*, selecciona la opción **`I want to create an IAM user`**.
   * En **Console password**, selecciona **`Custom password`** e ingresa: **`Tecsup00AA`** *(nota: si la cuenta tuviera una política personalizada que exija símbolos especiales, añade un carácter como `!` al final)*.
   * *(Práctica de laboratorio)* Desmarca la casilla **`Users must create a new password at next sign-in - Recommended`** únicamente para facilitar pruebas rápidas en este entorno. *(En producción, mantenla marcada).*
   * Haz clic en **`Next`**.
3. En la pantalla **Set permissions**:
   * Deja las opciones por defecto (sin seleccionar ningún grupo ni política todavía) y haz clic en **`Next`**.
4. En la pantalla **Review and create**:
   * Desplázate hasta la sección **Tags - optional** y haz clic en **`Add new tag`**:
     * **Key:** `Dev-Team`
     * **Value:** `Developers`
   * Revisa el resumen y haz clic en **`Create user`**.
5. En la pantalla de confirmación (**Retrieve password**):
   * Verás la URL de inicio de sesión (*Console sign-in URL*). Puedes descargar el archivo `.csv` si deseas probar el acceso luego.
   * Haz clic en **`Return to users list`** (si aparece una ventana de confirmación indicando que no descargaste la contraseña, haz clic en **`Continue`**).
6. **Repite exactamente los pasos 1 al 5** para crear un segundo usuario con los siguientes datos:
   * **User name:** `Sarah`
   * **Custom password:** `Tecsup00AA`
   * **Tag:** Key = `Dev-Team`, Value = `Developers`

#### Parte B: Crear los usuarios del equipo de Recursos Humanos (`Ted` y `Rita`)

7. Haz clic nuevamente en **`Create user`** y repite el procedimiento para crear a **`Ted`** y **`Rita`** con la siguiente configuración:
   * **User name:** `Ted` (y luego `Rita` en una segunda iteración).
   * **Console access:** Habilitado (`I want to create an IAM user`).
   * **Custom password:** `Tecsup00AA`
   * **Users must create a new password at next sign-in:** Desmarcado (solo para laboratorio).
   * **Set permissions:** Por defecto (sin permisos directos).
   * **Tag:**
     * **Key:** `HR-Team`
     * **Value:** `HR`
8. Al finalizar, en el listado de **`Users`**, verifica que existan los 4 usuarios creados: `John`, `Sarah`, `Ted` y `Rita`.

---

### Tarea 3: Crear Grupos de IAM, Asignar Usuarios y Adjuntar Políticas

Ahora agruparás a los usuarios según su función y les asignarás políticas administradas por AWS.

#### Parte A: Crear el grupo `Dev-Team`

1. En el panel izquierdo de IAM, selecciona **`User groups`** y haz clic en **`Create group`**.
2. En **User group name**, escribe: `Dev-Team`.
3. En la sección **Add users to the group - Optional**, busca y selecciona las casillas de **`John`** y **`Sarah`**.
4. En la sección **Attach permissions policies - Optional**:
   * En el buscador de políticas, escribe `AmazonEC2ReadOnlyAccess` y marca la casilla de la política **`AmazonEC2ReadOnlyAccess`**.
   * Limpia el filtro de búsqueda, escribe `AmazonS3ReadOnlyAccess` y marca la casilla de la política **`AmazonS3ReadOnlyAccess`**.
5. Haz clic en **`Create group`**.

#### Parte B: Crear el grupo `HR-Team`

6. Haz clic nuevamente en **`Create group`**.
7. En **User group name**, escribe: `HR-Team`.
8. En **Add users to the group - Optional**, selecciona las casillas de **`Ted`** y **`Rita`**.
9. En **Attach permissions policies - Optional**:
   * Busca y selecciona la política **`Billing`** *(o **`AWSBillingReadOnlyAccess`** si deseas aplicar el principio de mínimo privilegio para solo lectura de facturas)*.
10. Haz clic en **`Create group`**.
11. En la vista de **`User groups`**, verifica que ambos grupos muestren `2` usuarios asignados y estado **`Defined`** en la columna *Permissions*.

> **Nota importante sobre facturación en AWS:** En una cuenta real de AWS, aunque un usuario pertenezca a un grupo con la política `Billing` o `AWSBillingReadOnlyAccess`, el **Root User** debe haber habilitado previamente la opción *"Activate IAM Access"* en *Account Settings -> IAM User and Role Access to Billing Information* para que el usuario pueda visualizar la consola de Billing.

---

### Tarea 4: Validación del Laboratorio

Puedes validar la correcta configuración mediante la consola visual, el simulador de políticas o la CLI.

#### Validación 1: Inspección en la Consola de IAM
1. Ve a **`Users`** y haz clic en **`John`**:
   * En la pestaña **Permissions**, verifica que aparezca *"No policies attached directly"* y que herede `AmazonEC2ReadOnlyAccess` y `AmazonS3ReadOnlyAccess` a través del grupo `Dev-Team`.
   * En la pestaña **Groups**, confirma que pertenece a `Dev-Team`.
   * En la pestaña **Tags**, confirma `Dev-Team = Developers`.
2. Repite la comprobación con **`Ted`**, verificando su pertenencia al grupo `HR-Team`, su política heredada (`Billing`) y su etiqueta `HR-Team = HR`.

#### Validación 2: Prueba lógica con IAM Policy Simulator (Recomendado)
1. En el panel derecho del Dashboard de IAM (o ingresando a `https://policysim.aws.amazon.com/`), abre el **IAM Policy Simulator**.
2. En el panel izquierdo, en *Users*, selecciona **`John`**.
3. Realiza las siguientes simulaciones:
   * **Service:** `Amazon EC2` | **Action:** `DescribeInstances` → Haz clic en **Run Simulation**. Resultado esperado: **`allowed`** (permitido por `AmazonEC2ReadOnlyAccess`).
   * **Service:** `Amazon EC2` | **Action:** `RunInstances` → Haz clic en **Run Simulation**. Resultado esperado: **`denied`** (denegado implícitamente por falta de permisos de escritura).
   * **Service:** `Amazon S3` | **Action:** `ListAllMyBuckets` → Resultado esperado: **`allowed`**.
   * **Service:** `Amazon S3` | **Action:** `CreateBucket` → Resultado esperado: **`denied`**.
4. Cambia el usuario seleccionado a **`Ted`**:
   * **Service:** `AWS Billing` (o `Billing`) | **Action:** `GetBillingData` o `ViewBilling` → Resultado esperado: **`allowed`**.
   * **Service:** `Amazon EC2` | **Action:** `DescribeInstances` → Resultado esperado: **`denied`**.

#### Validación 3 (Opcional): Verificación vía AWS CLI / CloudShell
Si dispones de AWS CloudShell en la consola, puedes ejecutar los siguientes comandos para auditar los recursos creados:
```bash
aws iam list-users --query "Users[].UserName"
aws iam list-groups --query "Groups[].GroupName"
aws iam list-attached-group-policies --group-name Dev-Team
aws iam list-attached-group-policies --group-name HR-Team
```

---

### Tarea 5: Limpieza de Recursos (Solo si usas una cuenta propia)

Si realizaste este laboratorio en tu propia cuenta de AWS y no en un entorno efímero que se destruye automáticamente, elimina las identidades creadas para mantener tu cuenta limpia:

1. Ve a **IAM → User groups**:
   * Selecciona `Dev-Team` y `HR-Team` y elimínalos haciendo clic en **`Delete`**.
2. Ve a **IAM → Users**:
   * Selecciona `John`, `Sarah`, `Ted` y `Rita`, haz clic en **`Delete`** y confirma la eliminación.
3. Cierra sesión en la consola de AWS.

---

## 6. Dato Complementario: IAM Access Analyzer

Para auditar permisos en entornos reales, AWS ofrece **IAM Access Analyzer** (lanzado en diciembre de 2019 y ampliado en 2021 con validación y generación de políticas). Esta funcionalidad utiliza razonamiento automatizado para identificar recursos compartidos con entidades externas, detectar permisos no utilizados y generar políticas basadas en mínimo privilegio a partir de registros de AWS CloudTrail.

---

## 7. Conclusión

En este laboratorio:
* Creaste 4 usuarios de IAM (`John`, `Sarah`, `Ted`, `Rita`) con acceso a consola y etiquetas organizacionales.
* Creaste 2 grupos de IAM (`Dev-Team` y `HR-Team`) aplicando la buena práctica de asignar permisos a nivel de grupo y no directamente al usuario.
* Validaste el principio de mínimo privilegio comprobando qué acciones están permitidas y denegadas para cada perfil.
