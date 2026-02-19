variable "name" {
  description = "The name to use for the Lambda function"
  type        = string
  default     = "lambda-sample"
}

variable "create_url" {
  description = "Whether to create a Function URL"
  type        = bool
  default     = false
}
