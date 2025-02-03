output "dynamodb_table_name" {
  value = aws_dynamodb_table.incidencias.name
}

output "lambda_function_name" {
  value = aws_lambda_function.iot_lambda.function_name
}

output "iot_rule_name" {
  value = aws_iot_topic_rule.iot_rule.name
}
