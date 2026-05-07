output "vpc_id" {
  value = module.vpc.vpc_id
}

output "load_balancer_dns" {
  value       = aws_lb.app.dns_name
  description = "DNS name of the load balancer to access your application"
}

output "ec2_instance_ips" {
  value       = aws_instance.app[*].public_ip
  description = "Public IP addresses of EC2 instances"
}

output "postgres_endpoint" {
  value       = aws_db_instance.postgres.address
  description = "RDS PostgreSQL endpoint"
}

output "postgres_port" {
  value       = aws_db_instance.postgres.port
  description = "RDS PostgreSQL port"
}

output "free_tier_info" {
  value = "Resources used: 2x t2.micro EC2, 1x db.t2.micro RDS, ALB, VPC (750 hrs/mo free for 12 months)"
}
