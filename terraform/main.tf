terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------- USE EXISTING VPC + SUBNETS --------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_availability_zones" "available" {}

# -------------------- IAM ROLE FOR EKS --------------------
data "aws_iam_role" "eks_cluster_role" {
  name = "terraform-eks-cluster-role-2" # existing role
}

# -------------------- EKS CLUSTER --------------------
resource "aws_eks_cluster" "eks" {
  name     = "terraform-eks-cluster-2"
  role_arn = data.aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.default.ids
  }
}

# -------------------- ECR REPOSITORY --------------------
data "aws_ecr_repository" "app" {
  name = "my-simple-app-3" # existing repository
}

# -------------------- OUTPUTS --------------------
output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "ecr_repository_uri" {
  value = data.aws_ecr_repository.app.repository_url
}
