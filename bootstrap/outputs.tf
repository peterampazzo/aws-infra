output "state_bucket_name" {
  description = "Name of the S3 Terraform state bucket"
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 Terraform state bucket"
  value       = aws_s3_bucket.tfstate.arn
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role to set as AWS_ROLE_ARN in GitHub Actions variables"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
