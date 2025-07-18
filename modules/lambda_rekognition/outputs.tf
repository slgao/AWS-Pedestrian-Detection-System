output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.rekognition_function.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.rekognition_function.function_name
}

output "lambda_security_group_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}
