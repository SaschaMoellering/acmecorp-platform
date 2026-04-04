variable "route53_zone_name" {
  type = string
}

variable "gateway_ingress_host" {
  type = string
}

variable "grafana_ingress_host" {
  type = string
}

variable "gateway_alb_dns_name" {
  type    = string
  default = null
}

variable "gateway_alb_zone_id" {
  type    = string
  default = null
}

variable "grafana_alb_dns_name" {
  type    = string
  default = null
}

variable "grafana_alb_zone_id" {
  type    = string
  default = null
}

variable "enable_grafana_dns" {
  type    = bool
  default = false
}

data "aws_route53_zone" "public" {
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_route53_record" "gateway_alias" {
  count = var.gateway_alb_dns_name != null && var.gateway_alb_zone_id != null ? 1 : 0

  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.gateway_ingress_host
  type    = "A"

  alias {
    name                   = var.gateway_alb_dns_name
    zone_id                = var.gateway_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana_alias" {
  count = var.enable_grafana_dns && var.grafana_alb_dns_name != null && var.grafana_alb_zone_id != null ? 1 : 0

  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.grafana_ingress_host
  type    = "A"

  alias {
    name                   = var.grafana_alb_dns_name
    zone_id                = var.grafana_alb_zone_id
    evaluate_target_health = true
  }
}

output "zone_id" {
  value = data.aws_route53_zone.public.zone_id
}

output "gateway_hostname" {
  value = var.gateway_ingress_host
}

output "grafana_hostname" {
  value = var.grafana_ingress_host
}

output "gateway_record_fqdn" {
  value = try(aws_route53_record.gateway_alias[0].fqdn, null)
}

output "grafana_record_fqdn" {
  value = try(aws_route53_record.grafana_alias[0].fqdn, null)
}
