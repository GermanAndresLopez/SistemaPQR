**Arquitectura del Sistema PQR**

**Resumen**:
- Proyecto orientado a una aplicación SPA (frontend Vite/React) y una API backend (Node.js/Express) con bots (WhatsApp/Telegram). La infraestructura se despliega en AWS con ECS Fargate para contenedores, RDS para la base de datos, EFS para persistencia de sesiones de WhatsApp y CloudFront+ALB como puerta de entrada.

**Componentes principales**:
- **Frontend:** aplicación Vite/React. Actualmente desplegada como contenedor en ECS (imagen: `gandreslopez/valeria-frontend:latest`) y servida al público a través de CloudFront con origin en el ALB..
- **Backend:** API Node.js que corre en ECS Fargate (imagen: `gandreslopez/valeria-backend:latest`). Las variables y secretos se leen desde SSM Parameter Store.
- **ALB (Application Load Balancer):** enruta tráfico HTTP/HTTPS: la raíz y rutas estáticas al frontend target group; las rutas `/api/*` al backend target group. Listener y reglas configuradas en `Terraform/alb.tf`.
- **CloudFront CDN:** expone la aplicación al público con HTTPS y caching. Está configurado para usar el ALB como origin (root → frontend; `/api/*` → backend), ver `Terraform/cloudfront.tf`.
- **RDS (PostgreSQL):** base de datos relacional (privada, en subredes privadas). Retención de backups configurable (`db_backup_retention_period`), por defecto se dejó 0 para compatibilidad Free Tier — cambiar después del demo si se desea snapshots.
- **EFS:** sistema de archivos compartido para persistir `wa-auth/` (sesiones de WhatsApp) entre tareas y redespliegues, montado por el contenedor backend.
- **SSM Parameter Store:** almacena secretos (JWT, credenciales SMTP, tokens) y se referencia desde la tarea ECS para inyectar valores sensibles.
- **CloudWatch Logs:** grupos para backend y frontend: `/ecs/<project>-backend` y `/ecs/<project>-frontend`.

**Decisiones y razones (por qué)**:
- **ECS Fargate (contenedores):** permite desplegar backend y frontend como servicios gestionados sin administrar EC2s. Facilita escalado y despliegues (ideal para demo/prod).
- **ALB + CloudFront:** ALB maneja el enrutamiento interno entre frontend/backend; CloudFront añade CDN, HTTPS, reducción de latencia y reglas de caching. Usar ALB como origin es útil cuando el frontend está en ECS (contenedor), y mantiene coherencia con enrutar `/api/*` al mismo ALB.
- **EFS para `wa-auth/`:** las sesiones de WhatsApp necesitan persistencia entre reinicios y réplicas; EFS es la opción más sencilla para compartir archivos entre tareas Fargate.
- **SSM Parameter Store:** evita poner secretos en código o en `terraform.tfvars` público; las tareas ECS consumen secretos mediante ARNs.
- **Docker Hub en vez de ECR (ajuste temporal):** se usó `gandreslopez/*` en Docker Hub para simplificar el flujo de build/push en tu entorno; Terraform está preparado para usar imágenes públicas/privadas (se puede volver a ECR si prefieres).
- **Coste y compatibilidad Free Tier:** se configuró `db_backup_retention_period` a `0` por compatibilidad con cuentas Free Tier y para evitar errores al crear RDS en cuentas gratuitas. Puedes cambiarlo a `2` o `7` días luego del demo.

**Despliegue (resumen de pasos)**:
1. Construir y subir imágenes Docker:
   - Backend:
     ```bash
     cd backend
     docker build -t pqr-backend .
     docker tag pqr-backend:latest gandreslopez/valeria-backend:latest
     docker push gandreslopez/valeria-backend:latest
     ```
   - Frontend:
     ```bash
     cd frontend
     docker build -t pqr-frontend .
     docker tag pqr-frontend:latest gandreslopez/valeria-frontend:latest
     docker push gandreslopez/valeria-frontend:latest
     ```
2. Terraform (desde `Terraform/`):
   ```bash
   cd Terraform
   terraform init
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
   - Asegúrate de que `terraform.tfvars` contiene `backend_image_repository` y `frontend_image_repository` apuntando a tus repositorios en Docker Hub.
3. Forzar redeploy (si hace falta):
   ```bash
   aws ecs update-service --cluster $(terraform output -raw ecs_cluster_name) \
     --service $(terraform output -raw ecs_service_name) --force-new-deployment --region <tu-region>
   ```

**Notas operativas y consideraciones**:
- **Rollback / cambios rápidos:** si prefieres servir frontend desde S3 (build `dist/`), la configuración anterior estaba lista para ello; se puede revertir con cambios en `cloudfront.tf` y reintroducir el bucket S3 en Terraform.
- **Eliminar S3 del state:** en tu caso ya eliminamos la gestión del bucket S3 del estado de Terraform para que `apply` no lo toque.
- **Backups RDS:** mantener `db_backup_retention_period=0` evita errores en Free Tier; para producción usa >=2.
- **Seguridad:** las tareas ECS están en subredes privadas y el ALB está en subredes públicas; SSM y roles IAM limitan accesos. Revisa `Terraform/iam.tf` para permisos mínimos necesarios.
- **Escalado:** por defecto `desired_count = 1` para backend y frontend; los bots mantienen conexiones persistentes, por eso el backend no escala horizontalmente sin cambios en la arquitectura (separar bots y API es una opción a futuro).

**Archivos clave (en este repo)**:
- `Terraform/ecs.tf` — definiciones de tareas y servicios ECS (backend y frontend)
- `Terraform/alb.tf` — ALB, target groups y reglas de listener
- `Terraform/cloudfront.tf` — distribución CloudFront (ahora usando ALB como origin)
- `Terraform/terraform.tfvars` — variables sensibles y repositorios de imágenes
- `frontend/` — código fuente del frontend (Vite)
- `backend/` — código fuente del backend (Node.js)

---

Si quieres, puedo generar también un diagrama sencillo (Mermaid) que muestre el flujo: Usuario → CloudFront → ALB → (Frontend TG ó Backend TG) → ECS tasks → RDS/EFS/SSM. ¿Lo quieres ahora?