output "monitoring_url" {
  value = "${var.subdomain_prefix}.${var.domain_name}"
}

output "prometheus_url" {
  value = "prometheus.${var.subdomain_prefix}.${var.domain_name}"
}

output "pushgateway_url" {
  value = "push.${var.subdomain_prefix}.${var.domain_name}"
}

output "grafana_url" {
  value = "grafana.${var.subdomain_prefix}.${var.domain_name}"
}

output "alertmanager_url" {
  value = "alertmanager.${var.subdomain_prefix}.${var.domain_name}"
}

output "wireguard_url" {
  value = "wg.${var.subdomain_prefix}.${var.domain_name}"
}
