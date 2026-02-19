terraform {
  backend "s3" {
    bucket         = "devops-lab-tofu-state"
    key            = "td5/scripts/tofu/live/lambda-sample/backend.tf"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "devops-lab-tofu-state"
  }
}
