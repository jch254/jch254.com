# Deployment/Infrastructure

This project is deployed to AWS on S3. CloudFront is used as a CDN. Route 53 is used for DNS.

--

### Deployment Prerequisites

**All commands below must be run in the /infrastructure directory.**

To deploy to AWS, you must:

1. Install [Terraform](https://www.terraform.io/) and make sure it is in your PATH.
1. Set your AWS credentials using one of the following options:
   1. Set your credentials as the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
   1. Run `aws configure` and fill in the details it asks for.
   1. Run on an EC2 instance with an IAM Role.

#### Deploying infrastructure

1. `terraform init`
1. `terraform plan -var-file jch254.com.tfvars`
1. `terraform apply -var-file jch254.com.tfvars`

#### Updating infrastructure

1. Make necessary infrastructure code changes.
1. `terraform init`
1. `terraform plan -var-file jch254.com.tfvars`
1. `terraform apply -var-file jch254.com.tfvars`

#### Destroying infrastructure (use with care)

1. `terraform init`
1. `terraform plan -var-file jch254.com.tfvars`
