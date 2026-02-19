terraform {
  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

variable "endpoint" {
  description = "The endpoint URL to test"
  type        = string
}

data "http" "test_endpoint" {
  url = var.endpoint
}

output "status_code" {
  description = "HTTP status code from the endpoint"
  value       = data.http.test_endpoint.status_code
}

output "response_body" {
  description = "Response body from the endpoint"
  value       = data.http.test_endpoint.response_body
}
