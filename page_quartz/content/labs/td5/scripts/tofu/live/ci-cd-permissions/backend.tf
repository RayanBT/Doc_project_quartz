terraform {
  backend "s3" {
    bucket         = "devops-lab-tofu-state"
    key            = "td5/scripts/tofu/live/ci-cd-permissions/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "devops-lab-tofu-state"
  }
}
