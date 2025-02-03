terraform {
  backend "s3" {
    bucket         = "mi-terraform-bucket-poc"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}