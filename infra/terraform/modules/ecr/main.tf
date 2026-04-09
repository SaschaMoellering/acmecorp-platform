variable "name_prefix" {
  type = string
}

variable "repository_names" {
  type = list(string)
}

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.key
  force_delete         = true
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

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -Eeuo pipefail

      repo_name='${self.name}'
      digests="$(aws ecr list-images --repository-name "$repo_name" --query 'imageIds[].imageDigest' --output text 2>/dev/null || true)"

      if [[ -z "$digests" || "$digests" == "None" ]]; then
        exit 0
      fi

      for digest in $digests; do
        aws ecr batch-delete-image \
          --repository-name "$repo_name" \
          --image-ids imageDigest="$digest" \
          >/dev/null
      done
    EOT
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
