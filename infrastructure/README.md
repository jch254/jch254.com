# Infrastructure

Infrastructure for [jch254.com](https://jch254.com), managed with Terraform.
Cloudflare keeps the custom domain pointed at GitHub Pages, and AWS CodeBuild
is the primary deployment runner for the static site.

## What is managed

**DNS records** (`cloudflare_dns_record`)
- `jch254.com` CNAME → `jch254.github.io` (proxied)
- `www` CNAME → `jch254.github.io` (proxied)
- `drive` CNAME → `ghs.googlehosted.com` (proxied)
- `mail` CNAME → `ghs.googlehosted.com` (proxied)
- `jch254.com` MX records → Google Mail (aspmx.l.google.com, alt1-4.aspmx.l.google.com)

DNS records are managed through the shared `cloudflare-dns-records` module in
`terraform-modules`.

**Transform Rules** (`cloudflare_ruleset`)
- HTTP response header rewrite rule applying security headers on all requests:
  - `Content-Security-Policy`
  - `Permissions-Policy`
  - `Referrer-Policy`
  - `Strict-Transport-Security`
  - `X-Content-Type-Options`
  - `X-Frame-Options`

The response-header ruleset remains local because there is not yet a shared
Cloudflare response-header module in `terraform-modules`.

**CodeBuild deployment** (`aws_codebuild_project`)
- `jch254dotcom` applies Terraform, then builds the Astro site from GitHub
- deploy output is pushed to the `gh-pages` branch
- `GITHUB_TOKEN` is read from SSM Parameter Store by `buildspec.yml`
- `CLOUDFLARE_API_TOKEN` is read from SSM Parameter Store by `buildspec.yml`

**SSM token placeholders** (`ssm-parameter-placeholder`)
- `/jch254dotcom/github-token`
- `/jch254dotcom/cloudflare-api-token`

Terraform does not take a plaintext `cloudflare_api_token` variable. CodeBuild
loads `CLOUDFLARE_API_TOKEN` from SSM before running Terraform so the provider can
authenticate without storing the decrypted token in Terraform state.

## State

Remote state is stored in S3: `s3://jch254-terraform-remote-state/jch254dotcom-prod-infrastructure` (ap-southeast-4, encrypted).

## Deployment

`infrastructure/terraform` is the runnable Terraform root. Infrastructure is
applied by CodeBuild using `infrastructure/deploy-infrastructure.bash`.
The root `buildspec.yml` installs dependencies, applies Terraform, then builds
the Astro site and publishes `dist/` to the GitHub Pages branch.
If `codebuild_webhook_enabled` is `true`, the AWS account must already have
CodeBuild GitHub source credentials/connection configured so AWS can create the
repository webhook.

Default SSM token placeholders:

| Parameter | Description |
|---|---|
| `/jch254dotcom/github-token` | GitHub token used by CodeBuild to push `gh-pages` |
| `/jch254dotcom/cloudflare-api-token` | Cloudflare token used by Terraform |

`codebuild_cache_bucket` defaults to `jch254-codebuild-cache/jch254dotcom`;
set it to an empty string if that cache bucket should not be used.

The GitHub token should be a fine-grained token scoped to this repository with
`Contents: Read and write`.

The Cloudflare token should have Zone DNS Edit and Transform Rules Edit
permissions for `jch254.com`.

GitHub Actions deployment is disabled while the workflow is preserved as a
backup at `.github/workflows/deploy-gh-pages.yml.disabled`.

The disabled backup workflow mirrors the CodeBuild branch-push deployment path:
it builds Astro and pushes `dist/` to `gh-pages`. It does not use GitHub Pages
artifacts and does not apply Terraform.

## Local usage

```bash
cd infrastructure/terraform

# Authenticate with AWS (requires access to the S3 state bucket)
aws sso login  # or export AWS_* env vars

# For the first local/bootstrap apply, export a real Cloudflare token directly.
export CLOUDFLARE_API_TOKEN="..."

terraform init
terraform plan
terraform apply

# After Terraform creates the placeholder parameters, overwrite them with real values.
aws ssm put-parameter \
  --region ap-southeast-4 \
  --name /jch254dotcom/github-token \
  --type SecureString \
  --value "$GITHUB_TOKEN" \
  --overwrite

aws ssm put-parameter \
  --region ap-southeast-4 \
  --name /jch254dotcom/cloudflare-api-token \
  --type SecureString \
  --value "$CLOUDFLARE_API_TOKEN" \
  --overwrite
```

After the bootstrap apply, CodeBuild reads both tokens from SSM through the
root `buildspec.yml`.

## Reusable module candidates

This repo now uses existing shared modules for Cloudflare DNS records and SSM
token placeholders. Two useful follow-up modules for `terraform-modules` would
be:

- `cloudflare-response-headers`, wrapping the standard security-header ruleset
- `github-pages-codebuild-deploy`, composing the CodeBuild project, minimal IAM
  role, SSM token placeholders, and branch-push environment variables

### Importing existing resources

If resources already exist in Cloudflare and need to be brought under Terraform management:

```bash
# DNS records - get record IDs from Cloudflare dashboard or API
terraform import 'module.dns_records.cloudflare_dns_record.this["apex_github"]' <zone_id>/<record_id>

# Ruleset - get ruleset ID from Cloudflare dashboard or API
terraform import cloudflare_ruleset.response_headers <zone_id>/<ruleset_id>
```

Existing root-level DNS record state is mapped into the shared DNS module by
`terraform/moved.tf`; do not remove those moved blocks until after the migration
has been applied everywhere that still has the old addresses in state.
