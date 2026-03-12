provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "zone" {
  filter = {
    name = var.domain
  }
}

resource "cloudflare_dns_record" "apex_github" {
  content = "jch254.github.io"
  name    = var.domain
  proxied = true
  ttl     = 1
  type    = "CNAME"
  zone_id = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "www" {
  content = "jch254.github.io"
  name    = "www"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  zone_id = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "drive" {
  content = "ghs.googlehosted.com"
  name    = "drive"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  zone_id = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "mail" {
  content = "ghs.googlehosted.com"
  name    = "mail"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  zone_id = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "google_mx_1" {
  content  = "aspmx.l.google.com"
  name     = var.domain
  priority = 1
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "google_mx_2" {
  content  = "alt1.aspmx.l.google.com"
  name     = var.domain
  priority = 5
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "google_mx_3" {
  content  = "alt2.aspmx.l.google.com"
  name     = var.domain
  priority = 5
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "google_mx_4" {
  content  = "alt3.aspmx.l.google.com"
  name     = var.domain
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = data.cloudflare_zone.zone.id
}

resource "cloudflare_dns_record" "google_mx_5" {
  content  = "alt4.aspmx.l.google.com"
  name     = var.domain
  priority = 10
  proxied  = false
  ttl      = 1
  type     = "MX"
  zone_id  = data.cloudflare_zone.zone.id
}

resource "cloudflare_ruleset" "response_headers" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "default"
  kind    = "zone"
  phase   = "http_response_headers_transform"

  rules = [
    {
      description = "Security Headers"
      expression = "true"
      action     = "rewrite"

      action_parameters = {
        headers = {
          "Content-Security-Policy" = {
            operation = "set"
            value     = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; frame-src https://www.youtube-nocookie.com https://player.vimeo.com https://w.soundcloud.com https://open.spotify.com https://www.instagram.com https://embed.podcasts.apple.com; font-src 'self' https://fonts.gstatic.com; connect-src 'self'; upgrade-insecure-requests"
          }
          "Permissions-Policy" = {
            operation = "set"
            value     = "camera=(), microphone=(), geolocation=(), payment=()"
          }
          "Referrer-Policy" = {
            operation = "set"
            value     = "strict-origin-when-cross-origin"
          }
          "Strict-Transport-Security" = {
            operation = "set"
            value     = "max-age=31536000; includeSubDomains; preload"
          }
          "X-Content-Type-Options" = {
            operation = "set"
            value     = "nosniff"
          }
          "X-Frame-Options" = {
            operation = "set"
            value     = "DENY"
          }
        }
      }
    }
  ]
}
