output "function_name" {
  description = "The name of the Lambda function"
  value       = module.function.function_name
}

output "function_arn" {
  description = "The ARN of the Lambda function"
  value       = module.function.function_arn
}

output "function_url" {
  description = "The URL of the Lambda function"
  value       = var.create_url ? module.function.function_url : null
}
