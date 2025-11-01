variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "vpc_id" {
  description = "Use an existing VPC ID (leave empty to create a new VPC)"
  type        = string
  default     = ""
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "terraform-eks-cluster"
}

variable "eks_role_name" {
  description = "IAM role name for EKS cluster"
  type        = string
  default     = "terraform-eks-cluster-role"
}

variable "ecr_name" {
  description = "ECR repository name"
  type        = string
  default     = "my-simple-app1"
}
