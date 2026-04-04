# aws-infra

One-time setup to connect this repository to AWS using **OpenID Connect (OIDC)**. This eliminates the need for permanent AWS Access Keys in GitHub.

## Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [Terraform](https://www.terraform.io/) ~1.5+ installed

## Bootstrap Setup (One-Time Only)

### Phase 1: Create Temporary Bootstrap User

Since Terraform needs permissions to set up the OIDC trust relationship, create a temporary admin user:

```bash
# Create user
aws iam create-user --user-name terraform-bootstrap-user

# Grant administrator access
aws iam attach-user-policy \
  --user-name terraform-bootstrap-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Generate API credentials
aws iam create-access-key --user-name terraform-bootstrap-user
```

### Phase 2: Configure Local AWS Credentials

Export the credentials from Phase 1 to your terminal session:

```bash
export AWS_ACCESS_KEY_ID=AKIA_YOUR_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_DEFAULT_REGION=eu-north-1
```

### Phase 3: Deploy Infrastructure

Run the bootstrap Terraform:

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Note the `github_actions_role_arn` output value for the next step.

### Phase 4: Configure GitHub Actions

Set the repository variable in GitHub Settings → Secrets and Variables → Actions:

```
AWS_ROLE_ARN = arn:aws:iam::<account-id>:role/github-actions-tfstate
```

### Phase 5: Security Cleanup

Delete the temporary bootstrap user — OIDC handles authentication from this point forward:

```bash
# Delete the API key
aws iam delete-access-key \
  --user-name terraform-bootstrap-user \
  --access-key-id AKIA_YOUR_KEY_ID

# Remove permissions and delete user
aws iam detach-user-policy \
  --user-name terraform-bootstrap-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam delete-user --user-name terraform-bootstrap-user

# Clear environment variables
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
```

## Ongoing: CI/CD Workflow

Push changes to `main` → Terraform auto-applies. Open a PR → plan posted as a comment.