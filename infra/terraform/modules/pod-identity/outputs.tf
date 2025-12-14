output "orders_service_association_id" {
  description = "Orders service Pod Identity association ID"
  value       = aws_eks_pod_identity_association.orders_service.association_id
}

output "catalog_service_association_id" {
  description = "Catalog service Pod Identity association ID"
  value       = aws_eks_pod_identity_association.catalog_service.association_id
}

output "gateway_service_association_id" {
  description = "Gateway service Pod Identity association ID"
  value       = aws_eks_pod_identity_association.gateway_service.association_id
}