# Credenciales de Docker Hub para que ECS autentique los pulls de
# gandreslopez/valeria-backend y gandreslopez/valeria-frontend. Los pulls
# anonimos comparten el rate limit de la IP del NAT Gateway y terminan en
# "429 Too Many Requests"; con credenciales el limite es mucho mayor.

resource "aws_secretsmanager_secret" "dockerhub" {
  name = "${var.project_name}/${var.environment}/dockerhub-credentials"

  tags = {
    Name = "${var.project_name}-dockerhub-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "dockerhub" {
  secret_id = aws_secretsmanager_secret.dockerhub.id

  secret_string = jsonencode({
    username = var.dockerhub_username
    password = var.dockerhub_token
  })
}
