########################################
# EC2 Module Outputs
########################################

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sms_seller_connect_ec2.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.ec2_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.sms_seller_connect_ec2.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.sms_seller_connect_ec2.public_dns
}

# output "ec2_instance_profile_name" {
#   description = "Name of the EC2 instance profile"
#   value       = aws_iam_instance_profile.ec2_combined_profile.name
# }

output "ecr_repo_url" {
  value = data.aws_ecr_repository.sms_seller_connect.repository_url
}

output "route53_record_fqdn" {
  value       = "sms.${var.domain_name}"
  description = "The fully qualified domain name for the EC2 instance."
}

########################################
# ALB Outputs
########################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.ec2_apps.arn
}

########################################
# Security Group Outputs
########################################

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

########################################
# Domain Outputs
########################################

output "sms_frontend_url" {
  description = "URL for SMS frontend"
  value       = "https://${var.sms_frontend_domain}"
}

output "sms_api_url" {
  description = "URL for SMS API"
  value       = "https://${var.sms_api_domain}"
}

output "carrental_frontend_url" {
  description = "URL for Car Rental frontend (if enabled)"
  value       = var.enable_carrental_domain ? "https://${var.carrental_frontend_domain}" : null
}

output "carrental_api_url" {
  description = "URL for Car Rental API (if enabled)"
  value       = var.enable_carrental_domain ? "https://${var.carrental_api_domain}" : null
}

########################################
# S3 Outputs
########################################

output "config_bucket_name" {
  description = "Name of the S3 configuration bucket"
  value       = aws_s3_bucket.config_bucket.bucket
}

output "config_bucket_arn" {
  description = "ARN of the S3 configuration bucket"
  value       = aws_s3_bucket.config_bucket.arn
}

########################################
# S3 Bucket Outputs
########################################

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.sms_seller_connect_bucket.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.sms_seller_connect_bucket.id
}

########################################
# ACM Certificate Outputs
########################################

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "acm_certificate_domain" {
  description = "Domain name of the ACM certificate"
  value       = aws_acm_certificate.main.domain_name
}
