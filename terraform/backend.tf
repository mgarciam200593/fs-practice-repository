terraform {
  backend "s3" {
    bucket               = "fs-remote-backend"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
    workspace_key_prefix = "fullstack"
  }
}