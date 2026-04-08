
### Contexto del Caso: Optimización de la Experiencia de Usuario en "EcoStore"

La empresa ficticia **EcoStore** ha migrado su aplicación de carrito de compras a una arquitectura distribuida utilizando un Application Load Balancer (ALB). Sin embargo, se ha detectado que los usuarios pierden sus productos seleccionados al navegar por el sitio, ya que el balanceador redirige las solicitudes de forma aleatoria entre varios servidores, y la aplicación aún no cuenta con una base de datos de sesiones externa.

Para resolver esto de forma temporal y eficiente, se ha decidido implementar **Sesiones Adaptables (Sticky Sessions)**. Esta configuración permitirá que, una vez que un usuario establezca conexión con un servidor específico, todas sus solicitudes posteriores sean dirigidas al mismo nodo durante un tiempo determinado, garantizando la integridad de su sesión de compra.

---

### Guía Paso a Paso: Implementación de Sticky Sessions en AWS

#### Fase 1: Configuración del Entorno y Acceso
1. Se accede a la **Consola de Administración de AWS** utilizando las credenciales proporcionadas para el entorno de laboratorio.
2. La región de trabajo es establecida en **EE. UU. Este (N. Virginia) us-east-1**, asegurando que todos los recursos se desplieguen en la misma ubicación geográfica para minimizar la latencia.

#### Fase 2: Establecimiento de Políticas de Seguridad (Security Groups)
Para permitir el flujo de tráfico web, se requiere la creación de una entidad de seguridad:
1. En el panel de EC2, se selecciona la opción **Security Groups** y se procede a la creación de uno nuevo.
2. El nombre asignado es **SG-Web-Traffic** y se añade una descripción referente al control de tráfico para el balanceador y las instancias.
3. Se añade una **Regla de Entrada (Inbound Rule)**:
   - **Tipo:** HTTP (Puerto 80).
   - **Origen:** Anywhere-IPv4 (0.0.0.0/0).
4. El proceso es finalizado con la creación del grupo, dejando las reglas de salida por defecto (permitir todo).

#### Fase 3: Despliegue de la Infraestructura de Servidores (EC2)
Se procede al lanzamiento de dos nodos que actuarán como servidores web:
1. En la sección de **Instancias**, se selecciona **Launch Instances**.
2. **Nombre de la instancia:** Se define como `App-Server-Node`.
3. **Cantidad:** Se especifica el número **2** en el campo de "Number of instances".
4. **Imagen (AMI):** Se selecciona **Ubuntu**.
5. **Tipo de Instancia:** Se elige `t2.micro` (apta para la capa gratuita).
6. **Key Pair:** Se marca la opción "Proceed without a key pair", ya que el acceso SSH no es requerido para este ejercicio.
7. **Configuración de Red:**
   - Se selecciona el **Security Group** creado previamente (`SG-Web-Traffic`).
   - Se asegura que la asignación de IP pública esté en **Enable**.
8. **Detalles Avanzados (User Data):** En el campo de script de inicio, se introduce el siguiente código para automatizar la instalación del servidor web y personalizar la página de inicio con la IP interna de cada servidor:

```bash
#!/bin/bash
sudo su
apt update -y
apt install apache2 -y
echo "Servidor Activo - EcoStore - IP Interna: $(hostname -f)" > /var/www/html/index.html
systemctl start apache2
systemctl enable apache2
```
9. Las instancias son lanzadas y se espera hasta que su estado sea **Running**.

#### Fase 4: Configuración del Grupo de Destino y Balanceador (ALB)
Para distribuir el tráfico, se deben agrupar las instancias y crear el punto de entrada:
1. **Target Group:** Se crea un grupo llamado `TG-EcoStore-Apps`.
   - **Target type:** Instances.
   - **Protocolo:** HTTP:80.
   - Se seleccionan las dos instancias creadas y se presionan en **Include as pending below** para registrarlas.
2. **Application Load Balancer:** Se navega a la sección de **Load Balancers** y se crea uno de tipo "Application".
   - **Nombre:** `ALB-EcoStore-Main`.
   - **Esquema:** Internet-facing.
   - **Network Mapping:** Se seleccionan al menos dos zonas de disponibilidad (us-east-1a y us-east-1b).
   - **Security Groups:** Se asocia `SG-Web-Traffic`.
   - **Listeners and routing:** Se configura el puerto 80 para que reenvíe el tráfico al Target Group `TG-EcoStore-Apps`.

#### Fase 5: Activación de la Persistencia de Sesión (Sticky Sessions)
Una vez creado el balanceador, se debe modificar el comportamiento del Target Group:
1. Se accede a la configuración de `TG-EcoStore-Apps`.
2. Se selecciona la pestaña **Attributes** y se hace clic en **Edit**.
3. Se localiza la sección de **Stickiness**:
   - Se activa el checkbox de **Stickiness**.
   - **Tipo:** Load balancer generated cookie.
   - **Duración:** Se establece en **2 minutos**.
4. Los cambios son guardados exitosamente.

#### Fase 6: Validación de la Solución
1. Se copia el nombre DNS del balanceador (`ALB-EcoStore-Main`) y se pega en un navegador.
2. Se observa que el mensaje muestra la IP de uno de los servidores.
3. Se actualiza la página repetidamente. Debido a la configuración de **Sticky Sessions**, el navegador debe mostrar siempre la misma IP del servidor durante el periodo de 2 minutos, a pesar de que existan dos servidores disponibles.
4. Tras esperar el tiempo de expiración de la cookie (2 min) o abrir una ventana de incógnito, se comprueba que el balanceador puede redirigir la solicitud al otro servidor.

#### Fase 7: Finalización y Limpieza de Recursos
Para evitar costes innecesarios o mantener la higiene del entorno:
1. Las instancias EC2 son **terminadas**.
2. El balanceador de carga es **eliminado**.
3. El Target Group es **borrado**.
4. El Security Group es **removido**.
