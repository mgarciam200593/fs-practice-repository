provider "aws" {
  default_tags {
    tags = {
      "Environment"   = "${terraform.workspace}"
      "Certification" = "Devops"
      "Managed-by"    = "Terraform"
    }
  }
}