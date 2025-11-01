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

# -------------------- VPC + Subnets --------------------
data "aws_availability_zones" "available" {}

# Use existing VPC if provided
data "aws_vpc" "selected" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

# Create new VPC if not provided
resource "aws_vpc" "main" {
  count      = var.vpc_id == "" ? 1 : 0
  cidr_block = "10.0.0.0/16"
  tags = { Name = "terraform-vpc" }
}

resource "aws_internet_gateway" "gw" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.main[0].id
}

resource "aws_subnet" "public" {
  count                  = 2
  vpc_id                 = var.vpc_id != "" ? data.aws_vpc.selected[0].id : aws_vpc.main[0].id
  cidr_block             = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone      = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-${count.index}" }
}

# -------------------- IAM Role for EKS --------------------
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
  name               = var.eks_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_cluster_role.name
}

# -------------------- EKS Cluster --------------------
resource "aws_eks_cluster" "eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_cni_policy
  ]
}

# -------------------- ECR Repository --------------------
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
