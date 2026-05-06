variable "aws_region" {
  description = "AWS region for the CodeBuild deployment project."
  type        = string
  default     = "ap-southeast-4"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "prod"
}

variable "domain" {
  description = "Cloudflare zone name"
  type        = string
  default     = "jch254.com"
}

variable "cloudflare_api_token_parameter_name" {
  description = "SSM Parameter Store name containing the Cloudflare API token."
  type        = string
  default     = "/jch254dotcom/cloudflare-api-token"
}

variable "codebuild_project_name" {
  description = "Name of the CodeBuild project that deploys the static site."
  type        = string
  default     = "jch254dotcom"
}

variable "codebuild_source_location" {
  description = "GitHub repository URL used by the CodeBuild source."
  type        = string
  default     = "https://github.com/jch254/jch254.com.git"
}

variable "codebuild_buildspec" {
  description = "Path to the CodeBuild buildspec file."
  type        = string
  default     = "buildspec.yml"
}

variable "codebuild_build_compute_type" {
  description = "CodeBuild compute type."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_build_docker_image" {
  description = "Docker image to use as the CodeBuild build environment."
  type        = string
  default     = "aws/codebuild/standard"
}

variable "codebuild_build_docker_tag" {
  description = "Docker image tag to use as the CodeBuild build environment."
  type        = string
  default     = "7.0"
}

variable "codebuild_cache_bucket" {
  description = "Optional S3 bucket/prefix for CodeBuild dependency cache."
  type        = string
  default     = "jch254-codebuild-cache/jch254dotcom"
}

variable "github_token_parameter_name" {
  description = "SSM Parameter Store name containing the GitHub token used to push the Pages branch."
  type        = string
  default     = "/jch254dotcom/github-token"
}

variable "github_repository" {
  description = "GitHub owner/repo deployed by CodeBuild."
  type        = string
  default     = "jch254/jch254.com"
}

variable "pages_branch" {
  description = "Git branch served by GitHub Pages."
  type        = string
  default     = "gh-pages"
}

variable "build_output_dir" {
  description = "Astro build output directory published to GitHub Pages."
  type        = string
  default     = "dist"
}

variable "git_committer_name" {
  description = "Commit author name used for GitHub Pages deployment commits."
  type        = string
  default     = "jch254.com CodeBuild"
}

variable "git_committer_email" {
  description = "Commit author email used for GitHub Pages deployment commits."
  type        = string
  default     = "deploy@jch254.com"
}

variable "codebuild_webhook_enabled" {
  description = "Whether CodeBuild should deploy automatically on pushes to the source branch."
  type        = bool
  default     = true
}

variable "codebuild_webhook_branch" {
  description = "Git branch that triggers CodeBuild webhook builds."
  type        = string
  default     = "master"
}

variable "build_notifier_lambda_function_arn" {
  description = "Optional shared build-notifier Lambda ARN for CodeBuild success/failure notifications."
  type        = string
  default     = ""
}
