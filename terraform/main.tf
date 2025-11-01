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

# -------------------- VPC + SUBNETS --------------------
# Use the existing default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {}

# Get the first 2 subnets of the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -------------------- IAM ROLE FOR EKS --------------------
data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "terraform-eks-cluster-role-2"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# -------------------- EKS CLUSTER --------------------
resource "aws_eks_cluster" "eks" {
  name     = "terraform-eks-cluster-2"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_cni_policy
  ]
}

# -------------------- ECR REPOSITORY --------------------
# Reference the existing repository
data "aws_ecr_repository" "app" {
  name = "my-simple-app-2"
}

# -------------------- OUTPUTS --------------------
output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "ecr_repository_uri" {
  value = data.aws_ecr_repository.app.repository_url
}
