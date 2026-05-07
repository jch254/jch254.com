provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
    }
  }
}

provider "cloudflare" {}

data "aws_caller_identity" "current" {}

data "cloudflare_zone" "zone" {
  filter = {
    name = var.domain
  }
}

locals {
  codebuild_cache_bucket_parts = var.codebuild_cache_bucket == "" ? [] : split("/", var.codebuild_cache_bucket)
  codebuild_cache_bucket_name  = length(local.codebuild_cache_bucket_parts) > 0 ? local.codebuild_cache_bucket_parts[0] : ""
  codebuild_cache_bucket_prefix = length(local.codebuild_cache_bucket_parts) > 1 ? (
    join("/", slice(local.codebuild_cache_bucket_parts, 1, length(local.codebuild_cache_bucket_parts)))
  ) : ""
  codebuild_cache_object_arn = local.codebuild_cache_bucket_prefix != "" ? (
    "arn:aws:s3:::${local.codebuild_cache_bucket_name}/${local.codebuild_cache_bucket_prefix}/*"
    ) : (
    local.codebuild_cache_bucket_name != "" ? "arn:aws:s3:::${local.codebuild_cache_bucket_name}/*" : ""
  )
  remote_state_object_arn  = "arn:aws:s3:::${var.remote_state_bucket}/${var.remote_state_key}"
  codebuild_project_arn    = "arn:aws:codebuild:${var.aws_region}:${data.aws_caller_identity.current.account_id}:project/${var.codebuild_project_name}"
  codebuild_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.codebuild_project_name}-codebuild"
  codebuild_event_rule_arn = "arn:aws:events:${var.aws_region}:${data.aws_caller_identity.current.account_id}:rule/${var.codebuild_project_name}-*"

  build_notifier_region              = coalesce(var.build_notifier_region, var.aws_region)
  build_notifier_lambda_function_arn = "arn:aws:lambda:${local.build_notifier_region}:${data.aws_caller_identity.current.account_id}:function:${var.build_notifier_lambda_function_name}"

  cloudflare_dns_records = {
    apex_github = {
      content = "jch254.github.io"
      name    = var.domain
      proxied = true
      ttl     = 1
      type    = "CNAME"
    }
    www = {
      content = "jch254.github.io"
      name    = "www"
      proxied = true
      ttl     = 1
      type    = "CNAME"
    }
    drive = {
      content = "ghs.googlehosted.com"
      name    = "drive"
      proxied = true
      ttl     = 1
      type    = "CNAME"
    }
    mail = {
      content = "ghs.googlehosted.com"
      name    = "mail"
      proxied = true
      ttl     = 1
      type    = "CNAME"
    }
    google_mx_1 = {
      content  = "aspmx.l.google.com"
      name     = var.domain
      priority = 1
      proxied  = false
      ttl      = 1
      type     = "MX"
    }
    google_mx_2 = {
      content  = "alt1.aspmx.l.google.com"
      name     = var.domain
      priority = 5
      proxied  = false
      ttl      = 1
      type     = "MX"
    }
    google_mx_3 = {
      content  = "alt2.aspmx.l.google.com"
      name     = var.domain
      priority = 5
      proxied  = false
      ttl      = 1
      type     = "MX"
    }
    google_mx_4 = {
      content  = "alt3.aspmx.l.google.com"
      name     = var.domain
      priority = 10
      proxied  = false
      ttl      = 1
      type     = "MX"
    }
    google_mx_5 = {
      content  = "alt4.aspmx.l.google.com"
      name     = var.domain
      priority = 10
      proxied  = false
      ttl      = 1
      type     = "MX"
    }
  }

  codebuild_cache_statements = local.codebuild_cache_bucket_name == "" ? [] : [
    {
      Effect = "Allow"
      Action = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
      ]
      Resource = "arn:aws:s3:::${local.codebuild_cache_bucket_name}"
    },
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      Resource = local.codebuild_cache_object_arn
    },
  ]
}

module "cloudflare_api_token_parameter" {
  source = "github.com/jch254/terraform-modules//ssm-parameter-placeholder?ref=1.16.0"

  name        = var.cloudflare_api_token_parameter_name
  description = "Cloudflare API token for jch254.com Terraform"

  tags = {
    Environment = var.environment
  }
}

module "github_token_parameter" {
  source = "github.com/jch254/terraform-modules//ssm-parameter-placeholder?ref=1.16.0"

  name        = var.github_token_parameter_name
  description = "GitHub token for jch254.com CodeBuild Pages deploys"

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role" "codebuild_deploy" {
  name = "${var.codebuild_project_name}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.codebuild_project_name}-codebuild"
  }
}

resource "aws_iam_role_policy" "codebuild_deploy" {
  name = "${var.codebuild_project_name}-deploy"
  role = aws_iam_role.codebuild_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "logs:DescribeLogGroups",
            "logs:CreateLogGroup",
            "logs:DeleteLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:PutRetentionPolicy",
            "logs:ListTagsForResource",
            "logs:TagResource",
            "logs:UntagResource",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:DescribeParameters",
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:PutParameter",
            "ssm:DeleteParameter",
            "ssm:AddTagsToResource",
            "ssm:RemoveTagsFromResource",
            "ssm:ListTagsForResource",
          ]
          Resource = [
            module.github_token_parameter.arn,
            module.cloudflare_api_token_parameter.arn,
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetBucketLocation",
            "s3:ListBucket",
          ]
          Resource = "arn:aws:s3:::${var.remote_state_bucket}"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
          ]
          Resource = local.remote_state_object_arn
        },
        {
          Effect = "Allow"
          Action = [
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:GetRole",
            "iam:UpdateRole",
            "iam:ListRolePolicies",
            "iam:GetRolePolicy",
            "iam:PutRolePolicy",
            "iam:DeleteRolePolicy",
            "iam:PassRole",
            "iam:ListInstanceProfilesForRole",
            "iam:TagRole",
            "iam:UntagRole",
          ]
          Resource = local.codebuild_role_arn
        },
        {
          Effect = "Allow"
          Action = [
            "codebuild:CreateProject",
            "codebuild:DeleteProject",
            "codebuild:UpdateProject",
            "codebuild:BatchGetProjects",
            "codebuild:CreateWebhook",
            "codebuild:DeleteWebhook",
            "codebuild:UpdateWebhook",
          ]
          Resource = local.codebuild_project_arn
        },
        {
          Effect   = "Allow"
          Action   = ["sts:GetCallerIdentity"]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "events:PutRule",
            "events:DeleteRule",
            "events:DescribeRule",
            "events:PutTargets",
            "events:RemoveTargets",
            "events:ListTargetsByRule",
            "events:ListTagsForResource",
            "events:TagResource",
            "events:UntagResource",
          ]
          Resource = local.codebuild_event_rule_arn
        },
        {
          Effect = "Allow"
          Action = [
            "lambda:AddPermission",
            "lambda:RemovePermission",
            "lambda:GetPolicy",
          ]
          Resource = local.build_notifier_lambda_function_arn
        },
      ],
      local.codebuild_cache_statements,
    )
  })
}

module "codebuild_deploy_project" {
  source = "github.com/jch254/terraform-modules//codebuild-project?ref=1.16.0"

  name                               = var.codebuild_project_name
  description                        = "Build and deploy jch254.com to GitHub Pages"
  codebuild_role_arn                 = aws_iam_role.codebuild_deploy.arn
  build_compute_type                 = var.codebuild_build_compute_type
  build_docker_image                 = var.codebuild_build_docker_image
  build_docker_tag                   = var.codebuild_build_docker_tag
  privileged_mode                    = false
  image_pull_credentials_type        = "CODEBUILD"
  source_type                        = "GITHUB"
  source_location                    = var.codebuild_source_location
  buildspec                          = var.codebuild_buildspec
  git_clone_depth                    = 1
  cache_bucket                       = var.codebuild_cache_bucket
  badge_enabled                      = false
  create_log_group                   = true
  webhook_enabled                    = var.codebuild_webhook_enabled
  environment                        = var.environment
  build_notifier_lambda_function_arn = local.build_notifier_lambda_function_arn
  build_notifier_app_url             = "https://${var.domain}"
  build_notifier_github_repo_url     = trimsuffix(var.codebuild_source_location, ".git")

  webhook_filter_groups = [[
    {
      type    = "EVENT"
      pattern = "PUSH"
    },
    {
      type    = "HEAD_REF"
      pattern = "refs/heads/${var.codebuild_webhook_branch}"
    },
  ]]

  environment_variables = [
    { name = "AWS_DEFAULT_REGION", value = var.aws_region },
    { name = "REMOTE_STATE_BUCKET", value = var.remote_state_bucket },
    { name = "TF_STATE_KEY", value = var.remote_state_key },
    { name = "GITHUB_REPOSITORY", value = var.github_repository },
    { name = "PAGES_BRANCH", value = var.pages_branch },
    { name = "BUILD_OUTPUT_DIR", value = var.build_output_dir },
    { name = "GIT_COMMITTER_NAME", value = var.git_committer_name },
    { name = "GIT_COMMITTER_EMAIL", value = var.git_committer_email },
  ]
}

module "dns_records" {
  source = "github.com/jch254/terraform-modules//cloudflare-dns-records?ref=1.16.0"

  zone_id = data.cloudflare_zone.zone.id
  records = local.cloudflare_dns_records
}

module "response_headers" {
  source = "github.com/jch254/terraform-modules//cloudflare-response-headers?ref=1.16.0"

  zone_id = data.cloudflare_zone.zone.id
}
