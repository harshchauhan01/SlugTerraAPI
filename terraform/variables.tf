variable "project_name" {
  type        = string
  description = "Project prefix used in resource names"
  default     = "slugapi"
}

variable "environment" {
  type        = string
  description = "Environment name"
  default     = "dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR range"
  default     = "10.20.0.0/16"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnet CIDR blocks (free tier only uses public subnets)"
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "postgres_password" {
  type        = string
  description = "Password for RDS PostgreSQL (use strong password)"
  sensitive   = true
}
