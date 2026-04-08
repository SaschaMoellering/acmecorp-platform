variable "name_prefix" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "bucket_name_override" {
  type    = string
  default = null
}

variable "force_destroy_bucket" {
  type    = bool
  default = false
}

variable "public_hosted_zone_name" {
  type = string
}

variable "ui_subdomain" {
  type = string
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "public" {
  name         = var.public_hosted_zone_name
  private_zone = false
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

locals {
  bucket_name = coalesce(
    var.bucket_name_override,
    lower("${var.name_prefix}-ui-${data.aws_caller_identity.current.account_id}-${var.aws_region}")
  )
  origin_id     = "${var.name_prefix}-ui-origin"
  custom_domain = "${var.ui_subdomain}.${trim(var.public_hosted_zone_name, ".")}"
}

resource "aws_s3_bucket" "ui" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy_bucket

  tags = {
    Name = "${var.name_prefix}-ui"
  }
}

resource "aws_s3_bucket_versioning" "ui" {
  bucket = aws_s3_bucket.ui.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ui" {
  bucket = aws_s3_bucket.ui.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ui" {
  bucket = aws_s3_bucket.ui.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "ui" {
  name                              = "${var.name_prefix}-ui-oac"
  description                       = "Origin access control for ${var.name_prefix} UI bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "ui" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} UI"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = [local.custom_domain]

  origin {
    domain_name              = aws_s3_bucket.ui.bucket_regional_domain_name
    origin_id                = local.origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.ui.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.ui.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  depends_on = [aws_acm_certificate_validation.ui]
}

data "aws_iam_policy_document" "ui_bucket_policy" {
  statement {
    sid = "AllowCloudFrontRead"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.ui.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.ui.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "ui" {
  bucket = aws_s3_bucket.ui.id
  policy = data.aws_iam_policy_document.ui_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.ui]
}

resource "aws_acm_certificate" "ui" {
  provider = aws.us_east_1

  domain_name       = local.custom_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-ui"
  }
}

resource "aws_route53_record" "ui_certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ui.domain_validation_options :
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

resource "aws_acm_certificate_validation" "ui" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.ui.arn
  validation_record_fqdns = [for record in aws_route53_record.ui_certificate_validation : record.fqdn]
}

resource "aws_route53_record" "ui_alias_ipv4" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = local.custom_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.ui.domain_name
    zone_id                = aws_cloudfront_distribution.ui.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ui_alias_ipv6" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = local.custom_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.ui.domain_name
    zone_id                = aws_cloudfront_distribution.ui.hosted_zone_id
    evaluate_target_health = false
  }
}

output "bucket_name" {
  value = aws_s3_bucket.ui.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.ui.arn
}

output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.ui.domain_name
}

output "cloudfront_distribution_url" {
  value = "https://${aws_cloudfront_distribution.ui.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.ui.id
}

output "custom_domain" {
  value = local.custom_domain
}

output "custom_url" {
  value = "https://${local.custom_domain}"
}
