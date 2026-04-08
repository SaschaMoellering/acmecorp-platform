variable "name_prefix" {
  type = string
}

variable "public_hosted_zone_name" {
  type = string
}

variable "gateway_ingress_host" {
  type = string
}

variable "grafana_ingress_host" {
  type = string
}

data "aws_route53_zone" "public" {
  name         = var.public_hosted_zone_name
  private_zone = false
}

resource "aws_acm_certificate" "gateway" {
  domain_name       = var.gateway_ingress_host
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-gateway"
  }
}

resource "aws_route53_record" "gateway_validation" {
  for_each = {
    for dvo in aws_acm_certificate.gateway.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.public.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "gateway" {
  certificate_arn         = aws_acm_certificate.gateway.arn
  validation_record_fqdns = [for record in aws_route53_record.gateway_validation : record.fqdn]
}

resource "aws_acm_certificate" "grafana" {
  domain_name       = var.grafana_ingress_host
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-grafana"
  }
}

resource "aws_route53_record" "grafana_validation" {
  for_each = {
    for dvo in aws_acm_certificate.grafana.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.public.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "grafana" {
  certificate_arn         = aws_acm_certificate.grafana.arn
  validation_record_fqdns = [for record in aws_route53_record.grafana_validation : record.fqdn]
}

output "gateway_certificate_arn" {
  value = aws_acm_certificate_validation.gateway.certificate_arn
}

output "grafana_certificate_arn" {
  value = aws_acm_certificate_validation.grafana.certificate_arn
}

output "zone_id" {
  value = data.aws_route53_zone.public.zone_id
}
