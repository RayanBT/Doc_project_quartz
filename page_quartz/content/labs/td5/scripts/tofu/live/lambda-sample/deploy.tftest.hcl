run "deploy_lambda" {
  command = apply

  variables {
    create_url = true
  }

  assert {
    condition     = module.function.function_name == var.name
    error_message = "Function name mismatch: expected ${var.name}, got ${module.function.function_name}"
  }

  assert {
    condition     = module.function.function_arn != ""
    error_message = "Lambda function ARN should not be empty"
  }

  assert {
    condition     = length(regexall("^arn:aws:lambda:us-east-2:741989611871:function:", module.function.function_arn)) > 0
    error_message = "Function ARN should be a valid Lambda ARN in us-east-2"
  }

  assert {
    condition     = can(regex(var.name, module.function.function_arn))
    error_message = "Function ARN should contain function name ${var.name}"
  }

  assert {
    condition     = output.function_url != null
    error_message = "Function URL should be created when create_url is true"
  }
}

run "test_endpoint" {
  command = plan

  module {
    source = "../../modules/test-endpoint"
  }

  variables {
    endpoint = run.deploy_lambda.function_url
  }

  assert {
    condition     = data.http.test_endpoint.status_code == 200
    error_message = "Expected status code 200, got ${data.http.test_endpoint.status_code}"
  }

  assert {
    condition     = length(regexall("DevOps Labs!", data.http.test_endpoint.response_body)) > 0
    error_message = "Expected body to contain 'DevOps Labs!', got: ${data.http.test_endpoint.response_body}"
  }
}
