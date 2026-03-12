# Infrastructure

Cloudflare infrastructure for [jch254.com](https://jch254.com), managed with Terraform using the [Cloudflare provider v5](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs).

## What is managed

**DNS records** (`cloudflare_dns_record`)
- `jch254.com` CNAME → `jch254.github.io` (proxied)
- `www` CNAME → `jch254.github.io` (proxied)
- `drive` CNAME → `ghs.googlehosted.com` (proxied)
- `mail` CNAME → `ghs.googlehosted.com` (proxied)
- `jch254.com` MX records → Google Mail (aspmx.l.google.com, alt1-4.aspmx.l.google.com)

**Transform Rules** (`cloudflare_ruleset`)
- HTTP response header rewrite rule applying security headers on all requests:
  - `Content-Security-Policy`
  - `Permissions-Policy`
  - `Referrer-Policy`
  - `Strict-Transport-Security`
  - `X-Content-Type-Options`
  - `X-Frame-Options`

## State

Remote state is stored in S3: `s3://jch254-terraform-remote-state/jch254dotcom-prod-infrastructure` (ap-southeast-4, encrypted).

## Deployment

Infrastructure is deployed automatically via GitHub Actions on every push to `master`, after the build job succeeds. The workflow runs `terraform plan` then `terraform apply`.

### Required GitHub Actions secrets

| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | ARN of the IAM role assumed via OIDC to access S3 remote state |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Zone DNS Edit and Transform Rules Edit permissions |

The IAM role uses GitHub OIDC (no long-lived AWS credentials). It is scoped to this repo and has minimal S3 permissions — only read/write access to the state key.

## Local usage

```bash
cd infrastructure

export TF_VAR_cloudflare_api_token=<token>

# Authenticate with AWS (requires access to the S3 state bucket)
aws sso login  # or export AWS_* env vars

terraform init
terraform plan
terraform apply
```

### Importing existing resources

If resources already exist in Cloudflare and need to be brought under Terraform management:

```bash
# DNS records - get record IDs from Cloudflare dashboard or API
terraform import cloudflare_dns_record.<name> <zone_id>/<record_id>

# Ruleset - get ruleset ID from Cloudflare dashboard or API
terraform import cloudflare_ruleset.response_headers <zone_id>/<ruleset_id>
```
