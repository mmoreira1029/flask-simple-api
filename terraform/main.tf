variable "aws_access_key" {
  description = "AWS Access Key"
  type        = string
  default     = ""
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  default     = ""
}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_iam_policy" "load_balancer_controller_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("../eksctl/policies/alb.json")
}

output "policy_arn" {
  description = "The ARN of the IAM policy"
  value       = aws_iam_policy.load_balancer_controller_policy.arn
}

# resource "aws_iam_role" "load_balancer_controller_role" {
#   name = "AmazonEKSLoadBalancerControllerRole"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "eks.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       },
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "load_balancer_controller_attachment" {
#   policy_arn = aws_iam_policy.load_balancer_controller_policy.arn
#   role       = aws_iam_role.load_balancer_controller_role.name
# }

# output "role_arn" {
#   description = "The ARN of the IAM role"
#   value       = aws_iam_role.load_balancer_controller_role.arn
# }

resource "aws_cognito_user_pool" "user_pool" {
  name = "usergroup-1"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  tags = {
    Name = "usergroup-1"
  }
}

resource "aws_cognito_user_group" "user_group" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  name         = "usergroup-1"

  description = "Group for my application users"
  precedence  = 1
}

output "user_pool_id" {
  description = "The ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.user_pool.id
}

output "user_group_name" {
  description = "The name of the Cognito User Group"
  value       = aws_cognito_user_group.user_group.name
}

resource "aws_ecr_repository" "aws-load-balancer-controller" {
  name = "aws-load-balancer-controller"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "aws-load-balancer-controller"
  }
}

resource "aws_ecr_repository" "mx-wiki-engine" {
  name = "mx-wiki-engine"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "mx-wiki-engine"
  }
}

resource "aws_ecr_repository" "cert_manager_webhook" {
  name = "cert-manager-webhook"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
   lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "cert-manager-webhook"
  }
}

resource "aws_ecr_repository" "cert_manager_controller" {
  name = "cert-manager-controller"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "cert-manager-controller"
  }
}

resource "aws_ecr_repository" "cert_manager_cainjector" {
  name = "cert-manager-cainjector"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "cert-manager-cainjector"
  }
}

resource "aws_ecr_repository" "cert-manager-acmesolver" {
  name = "cert-manager-acmesolver"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "cert-manager-acmesolver"
  }
}

output "aws-load-balancer-controller" {
  description = "The URI of the cert-manager-webhook ECR repository"
  value       = aws_ecr_repository.aws-load-balancer-controller.repository_url
}

output "mx-wiki-engine_uri" {
  description = "The URI of the cert-manager-webhook ECR repository"
  value       = aws_ecr_repository.mx-wiki-engine.repository_url
}

output "cert_manager_webhook_uri" {
  description = "The URI of the cert-manager-webhook ECR repository"
  value       = aws_ecr_repository.cert_manager_webhook.repository_url
}

output "cert_manager_controller_uri" {
  description = "The URI of the cert-manager-controller ECR repository"
  value       = aws_ecr_repository.cert_manager_controller.repository_url
}

output "cert_manager_cainjector_uri" {
  description = "The URI of the cert-manager-cainjector ECR repository"
  value       = aws_ecr_repository.cert_manager_cainjector.repository_url
}

output "cert-manager-acmesolver" {
  description = "The URI of the cert-cert-manager-acmesolver-cainjector ECR repository"
  value       = aws_ecr_repository.cert-manager-acmesolver.repository_url
}

resource "aws_dynamodb_table" "users_table" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"

  hash_key     = "name"

  attribute {
    name = "name"
    type = "S"
  }

  tags = {
    Name = "Users Table"
  }
}

resource "aws_dynamodb_table" "groups_table" {
  name         = "Groups"
  billing_mode = "PAY_PER_REQUEST"

  hash_key     = "name"

  attribute {
    name = "name"
    type = "S"
  }

  tags = {
    Name = "Groups Table"
  }
}
