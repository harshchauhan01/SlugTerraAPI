aws_region        = "us-east-1"  # us-east-1 has better free tier coverage
project_name      = "slugapi"
environment       = "dev"

# Database configuration - FREE TIER
# RDS db.t2.micro: 750 hours/month free for 12 months
# IMPORTANT: Do NOT commit real secrets. Remove the password from this file
# and export it as an environment variable before running Terraform:
#
#   export TF_VAR_postgres_password="your-strong-password"
#
postgres_password = ""  # set via env var `TF_VAR_postgres_password`

# VPC configuration
vpc_cidr = "10.20.0.0/16"

# EC2: 2x t2.micro instances (750 hours/month each, free for 12 months)