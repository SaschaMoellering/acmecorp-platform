variable "public_hosted_zone_name" {
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

locals {
  manage_gateway_dns = var.gateway_alb_dns_name != null && var.gateway_alb_zone_id != null
  manage_grafana_dns = var.enable_grafana_dns && var.grafana_alb_dns_name != null && var.grafana_alb_zone_id != null
  manage_public_dns  = local.manage_gateway_dns || local.manage_grafana_dns
}

data "aws_route53_zone" "public" {
  count        = local.manage_public_dns ? 1 : 0
  name         = var.public_hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "gateway_alias" {
  count = local.manage_gateway_dns ? 1 : 0

  zone_id = data.aws_route53_zone.public[0].zone_id
  name    = var.gateway_ingress_host
  type    = "A"

  alias {
    name                   = var.gateway_alb_dns_name
    zone_id                = var.gateway_alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana_alias" {
  count = local.manage_grafana_dns ? 1 : 0

  zone_id = data.aws_route53_zone.public[0].zone_id
  name    = var.grafana_ingress_host
  type    = "A"

  alias {
    name                   = var.grafana_alb_dns_name
    zone_id                = var.grafana_alb_zone_id
    evaluate_target_health = true
  }
}

output "zone_id" {
  value = try(data.aws_route53_zone.public[0].zone_id, null)
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
