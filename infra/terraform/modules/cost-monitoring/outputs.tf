output "monthly_budget_name" {
  description = "Name of the monthly budget"
  value       = aws_budgets_budget.monthly.name
}

output "eks_budget_name" {
  description = "Name of the EKS budget"
  value       = aws_budgets_budget.eks.name
}