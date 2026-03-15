variable "name_prefix" {
  type = string
}

variable "repository_names" {
  type = list(string)
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.name_prefix}-${replace(each.key, "/", "-")}"
  }
}

output "repository_urls" {
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "repository_arns" {
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.arn
  }
}
