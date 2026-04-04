# aws-infra

This repository provisions the **shared AWS infrastructure** that all other repositories depend on:

1. **S3 bucket** — stores Terraform remote state for all repos in this GitHub profile
2. **GitHub Actions OIDC** — allows GitHub Actions workflows to authenticate to AWS without long-lived access keys

> This repo must be bootstrapped manually once before any other repo can use Terraform with remote state.

## CI/CD Workflow

- **Pull Request** → Terraform plan runs and posts output as a PR comment
- **Push to `main`** → Terraform apply runs automatically

## Adding New Repositories

1. Add the repo to `bootstrap/terraform.tfvars`:

```hcl
allowed_github_repos = [
  "peterampazzo/aws-infra",
  "peterampazzo/new-repo",  # <- add here
]
```

2. Apply:

```bash
eval "$(aws configure export-credentials --format env)"
terraform apply -var-file=terraform.tfvars
```

3. Set `AWS_ROLE_ARN` in the new repo's GitHub settings (same value as Phase 4 below).

## Local Development Notes

Terraform S3 backend requires credentials in environment variables. Before running any Terraform commands locally:

```bash
# If you see "no valid credential sources" errors, first clear any stale env vars:
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION

# Then export fresh credentials:
eval "$(aws configure export-credentials --format env)"
```

---

<details>
<summary><strong>Bootstrap Setup (one-time)</strong></summary>

### Prerequisites

- [AWS CLI](https://aws.amazon.com/cli/) installed and configured
- [Terraform](https://www.terraform.io/) ~1.5+ installed
- [GitHub CLI](https://cli.github.com/) (`gh`) — optional, for setting variables from the terminal

### Phase 1: Create Temporary Bootstrap User

Terraform needs elevated permissions to set up the OIDC trust and IAM resources:

```bash
# Create user
aws iam create-user --user-name terraform-bootstrap-user

# Grant administrator access
aws iam attach-user-policy \
  --user-name terraform-bootstrap-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Generate API credentials — note the AccessKeyId and SecretAccessKey
aws iam create-access-key --user-name terraform-bootstrap-user
```

### Phase 2: Configure Local AWS Credentials

Export the credentials into your current terminal session:

```bash
export AWS_ACCESS_KEY_ID=AKIA_YOUR_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_DEFAULT_REGION=eu-north-1
```

### Phase 3: Deploy Infrastructure

```bash
cd bootstrap
terraform init
eval "$(aws configure export-credentials --format env)"
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Note the `github_actions_role_arn` output — you'll need it in the next step.

### Phase 4: Configure GitHub Actions

Set this variable in the repo: **Settings → Secrets and Variables → Actions → Variables**

| Name | Value |
|------|-------|
| `AWS_ROLE_ARN` | `arn:aws:iam::<account-id>:role/github-actions-tfstate` |

Or via CLI:

```bash
gh variable set AWS_ROLE_ARN \
  --body "arn:aws:iam::<account-id>:role/github-actions-tfstate" \
  --repo peterampazzo/aws-infra
```

### Phase 5: Migrate Local State to S3

Uncomment the `backend "s3"` block in `bootstrap/providers.tf`, then:

```bash
eval "$(aws configure export-credentials --format env)"
terraform init -migrate-state
# Type 'yes' when prompted
```

### Phase 6: Security Cleanup

Delete the temporary bootstrap user — OIDC handles all authentication from this point:

```bash
aws iam delete-access-key \
  --user-name terraform-bootstrap-user \
  --access-key-id AKIA_YOUR_KEY_ID

aws iam detach-user-policy \
  --user-name terraform-bootstrap-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

aws iam delete-user --user-name terraform-bootstrap-user

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
```

</details>
