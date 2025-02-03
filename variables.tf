variable "lambda_s3_bucket" {
  description = "Bucket de S3 para el código de la Lambda"
  type        = string
}

variable "lambda_s3_key" {
  description = "Ruta del archivo ZIP en S3"
  type        = string
}