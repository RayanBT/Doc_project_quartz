provider "aws" {
  region = "us-east-2"
}

module "state" {
  source = "brikis98/devops/book//modules/state-bucket"
  version = "1.0.0"
  
  name = "devops-lab-tofu-state"
}
