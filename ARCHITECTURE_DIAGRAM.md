# Diagrama de Arquitectura AWS — pqr-clasificador (ValerIA)

Diagrama Mermaid generado a partir de la infraestructura definida en `Terraform/`.
Cuenta AWS `098567765142`, región `us-east-1`.

```mermaid
flowchart TB
    USER(["Usuario"])
    DOCKERHUB["Docker Hub\ngandreslopez/valeria-*"]

    subgraph AWS["AWS - cuenta 098567765142 - us-east-1"]
        CF["CloudFront\nd2xm7o3bvh8tpb.cloudfront.net\nHTTPS"]

        subgraph VPC["VPC 10.0.0.0/16"]
            subgraph PUB["Subredes publicas (2 AZ)"]
                ALB["Application Load Balancer (alb-sg)\ningress 80 desde 0.0.0.0/0"]
                NAT["NAT Gateway"]
            end

            subgraph PRIV["Subredes privadas (2 AZ)"]
                FRONTEND["ECS Fargate: Frontend (nginx)\nvaleria-frontend:latest - :80\nSG ecs-sg: 80 desde alb-sg"]
                BACKEND["ECS Fargate: Backend (Node/Express)\nvaleria-backend:latest - :3001\nSG ecs-sg: 3001 desde alb-sg"]
                RDS[("RDS PostgreSQL 16 (rds-sg)\n5432 desde ecs-sg")]
                EFS[("EFS wa-auth/ (efs-sg)\n2049 desde ecs-sg\nsesion WhatsApp Baileys")]
            end
        end

        SSM["SSM Parameter Store\nJWT, SMTP, OpenRouter, Telegram, etc."]
        SECRETS["Secrets Manager\ncredenciales Docker Hub"]
        LOGS["CloudWatch Logs\n/ecs/pqr-clasificador-*"]
    end

    subgraph EXTERNOS["Servicios externos"]
        WA["WhatsApp (Baileys)"]
        TG["Telegram Bot API"]
        OPENROUTER["OpenRouter API"]
        SMTP["SMTP Gmail"]
    end

    USER -->|HTTPS| CF
    CF -->|HTTP| ALB
    ALB -->|"/ (default)"| FRONTEND
    ALB -->|"/api/*"| BACKEND

    BACKEND -->|"5432/tcp"| RDS
    BACKEND -->|"NFS 2049"| EFS
    BACKEND -.->|lee secretos| SSM

    FRONTEND -.->|logs| LOGS
    BACKEND -.->|logs| LOGS

    SECRETS -.->|repositoryCredentials| FRONTEND
    SECRETS -.->|repositoryCredentials| BACKEND
    FRONTEND -.->|pull imagen| DOCKERHUB
    BACKEND -.->|pull imagen| DOCKERHUB

    BACKEND --> NAT
    NAT --> WA
    NAT --> TG
    NAT --> OPENROUTER
    NAT --> SMTP
```

## Recursos clave (Terraform)

| Componente | Recurso Terraform | Notas |
|---|---|---|
| CDN | `aws_cloudfront_distribution.frontend` | Origin = ALB, `/api/*` sin cache |
| Load Balancer | `aws_lb.main` | Listener HTTP :80 |
| Target groups | `aws_lb_target_group.backend` / `.frontend` | health check `/` → 200 |
| Cluster ECS | `aws_ecs_cluster.main` | Fargate |
| Servicio backend | `aws_ecs_service.backend` | task family `pqr-clasificador-backend`, puerto 3001 |
| Servicio frontend | `aws_ecs_service.frontend` | task family `pqr-clasificador-frontend`, puerto 80 |
| Base de datos | `aws_db_instance.main` | PostgreSQL 16, privada |
| Persistencia WhatsApp | `aws_efs_file_system.wa_auth` | montado en `/app/wa-auth` del backend |
| Secretos app | `Terraform/ssm.tf` | SSM Parameter Store (SecureString) |
| Credenciales Docker Hub | `Terraform/dockerhub.tf` | Secrets Manager + `repositoryCredentials` |
| Logs | `aws_cloudwatch_log_group.backend` / `.frontend` | `/ecs/pqr-clasificador-*` |
