variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "dockerhub_username" {
  description = "Your Docker Hub username"
  type        = string
  sensitive   = true
}