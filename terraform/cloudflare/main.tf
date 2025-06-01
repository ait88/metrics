# Create A record for the base monitoring URL
resource "cloudflare_record" "monitoring" {
  zone_id = var.cloudflare_zone_id
  name    = var.subdomain_prefix
  content   = var.frontend_ip
  type    = "A"
  ttl     = 1 # Auto TTL
  proxied = true # Use CloudFlare proxy for added security
}

# Create A record for Prometheus
resource "cloudflare_record" "prometheus" {
  zone_id = var.cloudflare_zone_id
  name    = "prometheus.${var.subdomain_prefix}"
  content   = var.frontend_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Create A record for Pushgateway
resource "cloudflare_record" "pushgateway" {
  zone_id = var.cloudflare_zone_id
  name    = "push.${var.subdomain_prefix}"
  content   = var.frontend_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Create A record for Grafana
resource "cloudflare_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "grafana.${var.subdomain_prefix}"
  content   = var.frontend_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Create A record for Alertmanager
resource "cloudflare_record" "alertmanager" {
  zone_id = var.cloudflare_zone_id
  name    = "alertmanager.${var.subdomain_prefix}"
  content   = var.frontend_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Optional: Create DNS records for WireGuard (typically not proxied)
resource "cloudflare_record" "wireguard" {
  zone_id = var.cloudflare_zone_id
  name    = "wg.${var.subdomain_prefix}"
  content   = var.frontend_ip
  type    = "A"
  ttl     = 1
  proxied = false # Don't proxy VPN traffic
}

# Create a Page Rule to enable specific caching for static content
#resource "cloudflare_page_rule" "grafana_caching" {
#  zone_id  = var.cloudflare_zone_id
#  target   = "grafana.${var.subdomain_prefix}.${var.domain_name}/public/*"
#  priority = 1
#
#  actions {
#    cache_level = "cache_everything"
#    edge_cache_ttl = 43200 # 12 hours
#  }
#}
#
# Optional: Create a Firewall rule to block malicious traffic
#resource "cloudflare_firewall_rule" "block_bad_bots" {
#  zone_id     = var.cloudflare_zone_id
#  description = "Block bad bots"
#  filter_id   = cloudflare_filter.bad_bots.id
#  action      = "block"
#}
#
#resource "cloudflare_filter" "bad_bots" {
#  zone_id     = var.cloudflare_zone_id
#  description = "Bad bots filter"
#  expression  = "(http.user_agent contains \"Baiduspider\") or (http.user_agent contains \"Yandex\")"
#}