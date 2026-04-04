variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = "Globally-unique name for the S3 Terraform-state bucket"
  type        = string
  default     = "rampazzo-tfstate"
}

variable "allowed_github_repos" {
  description = "List of GitHub repos in format 'org/repo' that can assume the role. Leave empty to allow all repos from any org."
  type        = list(string)
  default     = []
}
