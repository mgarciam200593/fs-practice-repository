provider "aws" {
  default_tags {
    tags = {
      "Environment" = "${var.environment}"
      "Project"     = "Fullstack Devops AWS+Terraform"
      "Managed By"  = "Terraform"
    }
  }
}