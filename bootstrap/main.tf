# ─────────────────────────────────────────────
# S3 bucket for Terraform remote state
# ─────────────────────────────────────────────

data "aws_caller_identity" "current" {}

locals {
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  github_actions_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-tfstate"
  tfstate_policy_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/tfstate-read-write"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of state history
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Deny any requests not sent over TLS
resource "aws_s3_bucket_policy" "tfstate_tls_only" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

# ─────────────────────────────────────────────
# GitHub Actions OIDC provider
# ─────────────────────────────────────────────

# AWS recommends supplying both thumbprints to cover GitHub's cert rotation.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprints for token.actions.githubusercontent.com
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# ─────────────────────────────────────────────
# IAM role assumed by any repo in the profile
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Allow specific repos or all repos if allowed_github_repos is empty
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = length(var.allowed_github_repos) > 0 ? [
        for repo in var.allowed_github_repos : "repo:${repo}:*"
      ] : ["repo:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-tfstate"
  description        = "Assumed by GitHub Actions workflows via OIDC to access TF state"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

# ─────────────────────────────────────────────
# IAM policy: read/write TF state in the bucket
# ─────────────────────────────────────────────

data "aws_iam_policy_document" "tfstate_rw" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }

  # Terraform in CI manages bootstrap resources too (bucket policy, OIDC provider,
  # role trust, and attached policies), so this role needs read/update permissions.
  statement {
    sid    = "BucketConfigurationManagement"
    effect = "Allow"
    actions = [
      "s3:GetBucket*",
      "s3:PutBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
    ]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid    = "OidcProviderManagement"
    effect = "Allow"
    actions = [
      "iam:ListOpenIDConnectProviders",
      "iam:GetOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
    ]
    resources = [local.github_oidc_provider_arn]
  }

  statement {
    sid    = "RoleManagement"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
    ]
    resources = [local.github_actions_role_arn]
  }

  statement {
    sid    = "ManagedPolicyVersionManagement"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListEntitiesForPolicy",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [local.tfstate_policy_arn]
  }
}

resource "aws_iam_policy" "tfstate_rw" {
  name        = "tfstate-read-write"
  description = "Read/write access to the Terraform state bucket"
  policy      = data.aws_iam_policy_document.tfstate_rw.json
}

resource "aws_iam_role_policy_attachment" "github_actions_tfstate" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.tfstate_rw.arn
}
