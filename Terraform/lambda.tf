# ─── Lambda: envío de correos (desacopla el SMTP del backend) ─────────────────
# El backend invoca esta función de forma asíncrona ("Event") en vez de usar
# nodemailer directamente. Reutiliza las mismas credenciales SMTP de Gmail
# (var.email_user / var.email_pass) ya usadas por el backend.

data "archive_file" "email_sender" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/email-sender"
  output_path = "${path.module}/.build/email-sender.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_email_sender" {
  name               = "${var.project_name}-lambda-email-sender-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_email_sender_logs" {
  role       = aws_iam_role.lambda_email_sender.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "email_sender" {
  name              = "/aws/lambda/${var.project_name}-email-sender"
  retention_in_days = 14
}

resource "aws_lambda_function" "email_sender" {
  function_name = "${var.project_name}-email-sender"
  role          = aws_iam_role.lambda_email_sender.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10

  filename         = data.archive_file.email_sender.output_path
  source_code_hash = data.archive_file.email_sender.output_base64sha256

  environment {
    variables = {
      EMAIL_HOST   = var.email_host
      EMAIL_PORT   = var.email_port
      EMAIL_SECURE = tostring(var.email_port == "465")
      EMAIL_USER   = var.email_user
      EMAIL_PASS   = var.email_pass
      EMAIL_FROM   = var.email_from
    }
  }

  depends_on = [aws_cloudwatch_log_group.email_sender]

  tags = {
    Name = "${var.project_name}-email-sender"
  }
}
