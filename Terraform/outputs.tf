output "alb_dns_name" {
  description = "DNS del Application Load Balancer (backend / API)"
  value       = aws_lb.main.dns_name
}

output "cloudfront_domain_name" {
  description = "Dominio de CloudFront para acceder al frontend"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "rds_endpoint" {
  description = "Endpoint (host) de la base de datos RDS"
  value       = aws_db_instance.main.address
}


/* frontend is now served via ALB -> CloudFront origin. S3 bucket not used. */

output "ecs_cluster_name" {
  description = "Nombre del cluster de ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nombre del servicio de ECS del backend"
  value       = aws_ecs_service.backend.name
}
