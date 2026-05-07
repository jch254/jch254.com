output "zone_id" {
  value = data.cloudflare_zone.zone.id
}

output "dns_record_ids" {
  description = "Cloudflare DNS record IDs keyed by record key."
  value       = module.dns_records.record_ids
}

output "response_headers_ruleset_id" {
  description = "Cloudflare response-header ruleset ID."
  value       = module.response_headers.id
}

output "cloudflare_api_token_parameter_name" {
  description = "SSM parameter name for the Cloudflare API token."
  value       = module.cloudflare_api_token_parameter.name
}

output "github_token_parameter_name" {
  description = "SSM parameter name for the GitHub Pages deployment token."
  value       = module.github_token_parameter.name
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project that deploys the static site."
  value       = module.codebuild_deploy_project.project_name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project that deploys the static site."
  value       = module.codebuild_deploy_project.project_arn
}

output "codebuild_role_arn" {
  description = "ARN of the IAM role used by the CodeBuild deployment project."
  value       = aws_iam_role.codebuild_deploy.arn
}

output "codebuild_build_notification_event_rule_arn" {
  description = "ARN of the optional CodeBuild notification EventBridge rule."
  value       = module.codebuild_deploy_project.build_notification_event_rule_arn
}
