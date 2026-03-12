variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Cloudflare zone name"
  type        = string
  default     = "jch254.com"
}