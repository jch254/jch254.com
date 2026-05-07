moved {
  from = cloudflare_dns_record.apex_github
  to   = module.dns_records.cloudflare_dns_record.this["apex_github"]
}

moved {
  from = cloudflare_dns_record.www
  to   = module.dns_records.cloudflare_dns_record.this["www"]
}

moved {
  from = cloudflare_dns_record.drive
  to   = module.dns_records.cloudflare_dns_record.this["drive"]
}

moved {
  from = cloudflare_dns_record.mail
  to   = module.dns_records.cloudflare_dns_record.this["mail"]
}

moved {
  from = cloudflare_dns_record.google_mx_1
  to   = module.dns_records.cloudflare_dns_record.this["google_mx_1"]
}

moved {
  from = cloudflare_dns_record.google_mx_2
  to   = module.dns_records.cloudflare_dns_record.this["google_mx_2"]
}

moved {
  from = cloudflare_dns_record.google_mx_3
  to   = module.dns_records.cloudflare_dns_record.this["google_mx_3"]
}

moved {
  from = cloudflare_dns_record.google_mx_4
  to   = module.dns_records.cloudflare_dns_record.this["google_mx_4"]
}

moved {
  from = cloudflare_dns_record.google_mx_5
  to   = module.dns_records.cloudflare_dns_record.this["google_mx_5"]
}
