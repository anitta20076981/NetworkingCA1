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

# -------------------- VARIABLES --------------------
variable "aws_region" {
  default = "eu-north-1"
}

variable "vpc_id" {
  type        = string
  description = "Use an existing VPC ID to avoid VPC limit exceeded error"
  default     = ""  # leave empty if you want to create new
}

# -------------------- VPC + SUBNETS --------------------
# Use existing VPC if provided, otherwise create new
data "aws_vpc" "selected" {
  count = var.vpc_id != "" ? 1 : 0
  id    = var.vpc_id
}

resource "aws_vpc" "main" {
  count      = var.vpc_id == "" ? 1 : 0
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terraform-vpc"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = var.vpc_id != "" ? data.aws_vpc.selected[0].id : aws_vpc.main[0].id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "gw" {
  count  = var.vpc_id == "" ? 1 : 0
  vpc_id = aws_vpc.main[0].id
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

data "aws_iam_role" "eks_cluster_role" {
  count = 1
  name  = "terraform-eks-cluster-role-2"
}

resource "aws_iam_role" "eks_cluster_role_create" {
  count               = length(data.aws_iam_role.eks_cluster_role) == 0 ? 1 : 0
  name                = "terraform-eks-cluster-role-2"
  assume_role_policy  = data.aws_iam_policy_document.eks_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.eks_cluster_role_create[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

  count = length(aws_iam_role.eks_cluster_role_create) > 0 ? 1 : 0
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  role       = aws_iam_role.eks_cluster_role_create[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  count = length(aws_iam_role.eks_cluster_role_create) > 0 ? 1 : 0
}

# -------------------- EKS CLUSTER --------------------
resource "aws_eks_cluster" "eks" {
  name     = "terraform-eks-cluster-2"
  role_arn = length(aws_iam_role.eks_cluster_role_create) > 0 ? aws_iam_role.eks_cluster_role_create[0].arn : data.aws_iam_role.eks_cluster_role[0].arn

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_cni_policy
  ]
}

# -------------------- ECR REPOSITORY --------------------
data "aws_ecr_repository" "app" {
  count = 1
  name  = "my-simple-app-2"
}

resource "aws_ecr_repository" "app_create" {
  count                = length(data.aws_ecr_repository.app) == 0 ? 1 : 0
  name                 = "my-simple-app-2"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# -------------------- OUTPUTS --------------------
output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "ecr_repository_uri" {
  value = length(aws_ecr_repository.app_create) > 0 ? aws_ecr_repository.app_create[0].repository_url : data.aws_ecr_repository.app[0].repository_url
}
