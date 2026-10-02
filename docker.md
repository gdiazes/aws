# Guía de Laboratorio: Orquestación de Contenedores en Amazon ECS con Instancias EC2 y Acceso Seguro vía SSM

---

## 1. Ficha Técnica y Objetivos de Aprendizaje

* **Nivel:** Intermedio - Fundacional.
* **Tiempo estimado:** 45 - 60 minutos.
* **Objetivos:**
  * **Comprender:** La arquitectura interna de ECS (Plano de control, ECS Agent, contenedor Pause y contenedores de aplicación).
  * **Aplicar:** El flujo de despliegue en ECS (*Cluster* $\rightarrow$ *Task Definition* $\rightarrow$ *Service*).
  * **Analizar:** El aislamiento de red en modo `awsvpc` y el comportamiento del orquestador ante fallos de tareas.
  * **Evaluar:** Las diferencias de seguridad operativa entre accesos tradicionales vía SSH vs. AWS Systems Manager.

---

## 2. Arquitectura de la Solución

```text
                             [ Usuario / Internet ]
                                       │
                                       │ HTTP (Puerto 80)
                                       ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ VPC (Default)                                                          │
 │ Security Group: ecs-workload-sg [Entrada: Solo Puerto 80 | Salida: ALL]│
 │                                                                        │
 │   ┌─────────────────────────────────────────────────────────────────┐  │
 │   │ Instancia EC2 (Amazon Linux 2023 - ECS Optimized)               │  │
 │   │ IAM Role: ecs-ec2-instance-role (Políticas: ECS + SSM)          │  │
 │   │                                                                 │  │
 │   │   ┌──────────────────────┐     ┌────────────────────────────┐   │  │
 │   │   │ Contenedor App       │     │ amazon-ecs-agent           │   │  │
 │   │   │ (httpd:2.4)          │     │ (Comunica con ECS API)     │   │  │
 │   │   │ ENI propia (awsvpc)  │     └──────────────┬─────────────┘   │  │
 │   │   └──────────┬───────────┘                    │                 │  │
 │   │              │ awslogs                        │                 │  │
 │   └──────────────┼────────────────────────────────┼─────────────────┘  │
 └──────────────────┼────────────────────────────────┼────────────────────┘
                    ▼                                ▼
       [ Amazon CloudWatch Logs ]       [ AWS Systems Manager Console ]
        (/ecs/httpd-task-def)            (Acceso seguro sin puerto 22)
```

---

## 3. Guía Paso a Paso con Andamiaje Cognitivo

---

### Fase 1: Preparación del Perfil de Seguridad e IAM (Fundamentos)

> **¿Por qué hacemos esto?**  
> Para administrar la instancia EC2 sin exponer llaves SSH ni abrir el puerto 22 a Internet, utilizaremos **AWS Systems Manager (SSM)**. Para ello, la instancia necesita permisos explícitos para comunicarse con los endpoints de ECS y SSM.

1. En la consola de AWS, navega a **IAM** > **Roles** y haz clic en **Create role**.
2. **Entidad de confianza (Trusted entity type):** Selecciona **AWS service**, y en caso de uso elige **EC2**.
3. **Políticas de permisos (Permissions policies):** Busca y selecciona las siguientes dos políticas gestionadas:
   * `AmazonEC2ContainerServiceforEC2Role` (permite a la instancia unirse al clúster de ECS).
   * `AmazonSSMManagedInstanceCore` (permite administrar la instancia vía Session Manager sin llaves SSH).
4. **Nombre del rol:** Asigna `ecs-ec2-host-role`.
5. Haz clic en **Create role**.

---

### Fase 2: Configuración del Grupo de Seguridad (Network Security)

1. Dirígete a la consola de **EC2** > menú lateral **Security Groups** (Grupos de seguridad).
2. Haz clic en **Create security group**.
3. **Detalles básicos:**
   * **Security group name:** `ecs-workload-sg`
   * **Description:** `Permitir trafico HTTP al servicio ECS y salida segura`
   * **VPC:** Selecciona tu **Default VPC**.
4. **Reglas de entrada (Inbound rules):**
   * Haz clic en **Add rule**:
     * **Type:** `HTTP`
     * **Port range:** `80`
     * **Source:** `Anywhere-IPv4` (`0.0.0.0/0`)
   *(Nota: Observa que no agregamos el puerto 22. Siguiendo el principio de menor privilegio, el acceso administrativo se gestionará vía SSM por HTTPS saliente).*
5. Haz clic en **Create security group**.

---

### Fase 3: Creación del Clúster de ECS con Cómputo EC2

1. Ve al servicio **Amazon ECS** y en el menú lateral haz clic en **Clusters**.
2. Haz clic en **Create cluster**.
3. **Configuración del Clúster:**
   * **Cluster name:** `production-ecs-cluster`
4. **Infraestructura (Infrastructure):**
   * Selecciona: **Amazon EC2 instances**.
   * **Auto Scaling group (ASG):** Marca **Create new Auto Scaling group**.
   * **Operating system/Architecture:** `Amazon Linux 2023`.
   * **EC2 instance type:** `t2.micro` (apto para Free Tier) o `t3.micro`.
   * **EC2 instance role:** Selecciona el rol creado en la Fase 1 (`ecs-ec2-host-role`).
   * **Desired capacity:**
     * **Mínimo:** `1`
     * **Máximo:** `2`
   * **SSH Key pair:** Selecciona **None** (No es necesario gracias a SSM).
5. **Configuración de Red (Networking):**
   * **VPC:** Tu **Default VPC**.
   * **Subnets:** Selecciona al menos 2 subredes públicas disponibles.
   * **Security group:** Selecciona **Use an existing security group** y elige `ecs-workload-sg`.
   * **Auto-assign public IP:** `Turn on` (Activado).
6. Haz clic en **Create**.

> **Checkpoint de Validación 1:**  
> Ve a la consola de **EC2**. Debes ver una instancia en estado `Running` con la etiqueta de Auto Scaling asociada a tu clúster. Si vas a **Systems Manager** > **Session Manager**, la instancia debe aparecer listada como nodo gestionado.

---

### Fase 4: Creación de la Definición de Tarea (Task Definition) con Logs

1. En el menú de ECS, haz clic en **Task definitions** > **Create new task definition** > **Create new task definition**.
2. **Parámetros de la Tarea:**
   * **Task definition family:** `httpd-task-def`
3. **Requisitos de Infraestructura:**
   * **Launch type:** Marca únicamente **Amazon EC2 instances**.
   * **Network mode:** Mantén el valor por defecto (`awsvpc`).
   * **CPU:** `0.25 vCPU`
   * **Memoria:** `0.5 GB`
   * **Task role:** `None`
   * **Task execution role:** Selecciona **Create new role** o `ecsTaskExecutionRole` *(Este rol permite al agente descargar la imagen y transmitir logs a CloudWatch)*.
4. **Configuración del Contenedor:**
   * **Name:** `apache-web`
   * **Image URI:** `httpd:2.4`
   * **Essential container:** `Yes`
   * **Port mappings:**
     * **Container port:** `80`
     * **Protocol:** `TCP`
     * **App protocol:** `HTTP`
5. **Observabilidad (Logging):**
   * En la sección inferior de **Logging**, asegúrate de que la casilla **Use log collection** esté marcada.
   * Selecciona **Amazon CloudWatch** con el grupo `/ecs/httpd-task-def` para almacenar las trazas de acceso del contenedor.
6. Haz clic en **Create**.

---

### Fase 5: Despliegue del Servicio ECS (Desired State)

1. En la pantalla de la definición de tarea recién creada (`httpd-task-def`), haz clic en **Deploy** > **Create service**.
2. **Configuración del Servicio:**
   * **Existing cluster:** `production-ecs-cluster`
   * **Compute configuration:** Selecciona **Launch type** > `EC2`.
   * **Service name:** `apache-service`
   * **Service type:** `Replica`
   * **Desired tasks:** `1`
3. **Redes (Networking):**
   * **VPC:** Default VPC.
   * **Security Group:** Elige **Use an existing security group** y selecciona `ecs-workload-sg`.
4. Haz clic en **Create**.
5. Espera unos instantes hasta que la pestaña **Deployments and tasks** indique `1/1 Running tasks`.

---

### Fase 6: Validación Funcional (Prueba de Tráfico Web)

1. Dentro de tu clúster, ve a la pestaña **Tasks (Tareas)** y haz clic sobre el ID de la tarea en ejecución.
2. En la sección **Network bindings / Configuration**, ubica la dirección **Public IP** asignada a la tarea (al usar modo `awsvpc`, cada tarea tiene su propia interfaz de red y su propia IP).
3. Abre una pestaña en tu navegador web e ingresa:
   ```text
   http://<IP_PUBLICA_DE_LA_TAREA>
   ```
4. **Resultado esperado:** Debes visualizar la página predeterminada:
   ```html
   <h1>It works!</h1>
   ```

---

### Fase 7: Inspección Profunda y Forense con AWS Systems Manager

> **¿Por qué hacemos esto?**  
> Para comprender la arquitectura interna sin vulnerar el host con puertos SSH abiertos, utilizaremos la consola segura de Session Manager para inspeccionar los contenedores a nivel de sistema operativo.

1. En la barra de búsqueda de AWS, escribe **Systems Manager**.
2. En el menú lateral, selecciona **Session Manager** y haz clic en **Start session**.
3. Selecciona tu instancia EC2 asociada al clúster de ECS y haz clic en **Start session**. Se abrirá una terminal Linux segura en el navegador.
4. Escala privilegios para tener control del daemon de Docker:
   ```bash
   sudo su -
   ```
5. Inspecciona los procesos de contenedores activos:
   ```bash
   docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.Status}}\t{{.Names}}"
   ```
6. **Análisis de Arquitectura:** Identifica los tres componentes clave en la salida:
   * `amazon/amazon-ecs-agent:latest`: Proceso que mantiene la conexión sincrónica con el plano de control de ECS.
   * `amazon/amazon-ecs-pause`: Contenedor "placeholder" que sostiene el namespace de red (`awsvpc`) para que la tarea conserve su IP aunque el contenedor principal se reinicie.
   * `httpd:2.4`: El proceso Apache activo.

---

## 4. Guía de Diagnóstico y Resolución de Problemas (Troubleshooting)

| Síntoma | Causa Raíz Probable | Solución Técnica |
| :--- | :--- | :--- |
| El navegador da `Timeout` al consultar la IP pública. | Falta la regla del puerto 80 en el Security Group de la tarea. | Ve a **EC2 > Security Groups > `ecs-workload-sg`** y verifica que exista una regla Inbound: `HTTP (80)` desde `0.0.0.0/0`. |
| La instancia EC2 no se une al clúster de ECS (0 Container instances). | El rol de IAM de la instancia no tiene la política requerida o la VPC no tiene salida a Internet. | Confirma que `ecs-ec2-host-role` contenga la política `AmazonEC2ContainerServiceforEC2Role`. |
| La instancia no aparece en AWS Systems Manager Session Manager. | Falta el agente de SSM o la política de IAM correspondiente. | Verifica que la política `AmazonSSMManagedInstanceCore` esté asociada al rol de la instancia EC2. |
| El estado de la tarea oscila entre `PENDING` y `STOPPED` (*CrashLoop*). | Memoria insuficiente o error al descargar la imagen de Docker Hub. | Ve a la tarea en la consola de ECS, abre la pestaña de detalles y revisa el mensaje en **Stopped reason**. |

---

## 5. Desafío de Transferencia Práctica (Active Learning)

Para consolidar tu aprendizaje, realiza de forma autónoma el siguiente reto:

> **El Desafío del Autocuidado (Self-Healing):**  
> 1. Desde tu sesión de terminal en Systems Manager (Fase 7), fuerza la detención del contenedor de Apache usando su ID:
>    ```bash
>    docker stop <ID_DEL_CONTENEDOR_HTTPD>
>    ```
> 2. Vuelve a ejecutar `docker ps` inmediatamente y observa qué sucede.
> 3. **Pregunta de reflexión:** ¿Por qué aparece un nuevo contenedor con un ID distinto a los pocos segundos?  
>    *(Pista: Analiza el concepto de "Desired State" que gestiona el ECS Service).*

---

## 6. Limpieza de Recursos (Well-Architected: Cost Optimization)

Para evitar cargos innecesarios en tu cuenta de AWS, retira los recursos creados en este orden:

1. **ECS Service:** Entra al servicio `apache-service`, haz clic en **Delete**, escribe `delete` y confirma la eliminación forzada.
2. **ECS Cluster:** Elimina `production-ecs-cluster`. Esto terminará automáticamente el Auto Scaling Group y la instancia EC2 asociada.
3. **CloudWatch Log Group:** Ve a CloudWatch > **Log groups** y elimina `/ecs/httpd-task-def`.
4. **Security Group:** En EC2 > **Security Groups**, elimina `ecs-workload-sg` una vez que la instancia haya terminado completamente.
5. **IAM Role:** Elimina el rol `ecs-ec2-host-role` si no lo necesitas para futuros laboratorios.
