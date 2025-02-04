provider "aws" {
  region = "us-east-1"
}
##############################
# 2. Bucket S3 para el ZIP de Lambda
##############################
resource "aws_s3_bucket" "lambda_bucket_poc" {
  bucket        = "my-lambda-report-bucket-poc"
  force_destroy = true
}

# resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
#   bucket = aws_s3_bucket.lambda_bucket_poc.id
#   policy = jsonencode({
#     Version   = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "AllowLambdaGetObject",
#         Effect    = "Allow",
#         Principal = "*",
#         Action    = "s3:GetObject",
#         Resource  = "${aws_s3_bucket.lambda_bucket_poc.arn}/*"
#       }
#     ]
#   })
# }

# Opción A: Desactivar bloqueo de políticas públicas para poder aplicar la política
resource "aws_s3_bucket_public_access_block" "lambda_bucket_access" {
  bucket                  = aws_s3_bucket.lambda_bucket_poc.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# DynamoDB
resource "aws_dynamodb_table" "incidencias" {
  name           = "IncidenciasMantenimiento"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "incidenciaId"

  attribute {
    name = "incidenciaId"
    type = "S"
  }
}

# IAM Role para Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_iot_dynamodb_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Permisos de Lambda para DynamoDB
resource "aws_iam_policy" "dynamodb_policy" {
  name   = "LambdaDynamoDBAccessPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["dynamodb:PutItem", "dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:UpdateItem"],
        Resource = aws_dynamodb_table.incidencias.arn
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "*"
      },{
        Effect = "Allow",
        Action = ["lambda:UpdateFunctionCode"],
        Resource = aws_lambda_function.iot_lambda.arn
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.lambda_bucket_poc.arn}/*"
      }
    ]
  })
}

# Asignar la política al rol de Lambda
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# Lambda desde S3
resource "aws_lambda_function" "iot_lambda" {
  function_name = "TemperatureAlertHandler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "com.iotPoc.TemperatureAlertHandler::handleRequest"
  runtime       = "java17"

  s3_bucket = aws_s3_bucket.lambda_bucket_poc.id
  s3_key    = var.lambda_s3_key

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.incidencias.name
    }
  }
}

# Regla de IoT Core
resource "aws_iot_topic_rule" "iot_rule" {
  name        = "HighTemperatureRule"
  sql         = "SELECT * FROM 'data' WHERE Temperatura > 49"
  sql_version = "2016-03-23"
  enabled     = true

  lambda {
    function_arn = aws_lambda_function.iot_lambda.arn
  }
}

# Permiso para que IoT invoque Lambda
resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowIoTInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_lambda.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.iot_rule.arn
}
