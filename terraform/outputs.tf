output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "ecr_repository_uri" {
  value = aws_ecr_repository.app.repository_url
}
