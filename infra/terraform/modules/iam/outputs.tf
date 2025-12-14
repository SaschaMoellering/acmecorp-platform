output "orders_service_role_arn" {
  description = "Orders service IAM role ARN"
  value       = aws_iam_role.orders_service.arn
}

output "catalog_service_role_arn" {
  description = "Catalog service IAM role ARN"
  value       = aws_iam_role.catalog_service.arn
}

output "gateway_service_role_arn" {
  description = "Gateway service IAM role ARN"
  value       = aws_iam_role.gateway_service.arn
}

output "billing_service_role_arn" {
  description = "Billing service IAM role ARN"
  value       = aws_iam_role.billing_service.arn
}

output "notification_service_role_arn" {
  description = "Notification service IAM role ARN"
  value       = aws_iam_role.notification_service.arn
}

output "analytics_service_role_arn" {
  description = "Analytics service IAM role ARN"
  value       = aws_iam_role.analytics_service.arn
}