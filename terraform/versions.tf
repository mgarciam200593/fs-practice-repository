# In this file put all the logic to crete the proper infraestructure
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=6.0"
    }
  }
  required_version = ">=1.4"
}
