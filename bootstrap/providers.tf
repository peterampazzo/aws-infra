terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # -----------------------------------------------------------------------
  # After the first manual `terraform apply`, uncomment this backend block,
  # then run:  terraform init -migrate-state
  # -----------------------------------------------------------------------
  # backend "s3" {
  #   bucket = "rampazzo-tfstate"
  #   key    = "bootstrap/terraform.tfstate"
  #   region = "eu-north-1"
  # }
}

provider "aws" {
  region = var.aws_region
}
