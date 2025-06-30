# ########################################
# # Import Configuration for Existing Resources
# ########################################
# 
# # This file contains import blocks for existing resources
# # Uncomment and modify as needed to import existing infrastructure
# 
# # Example: Import existing EC2 instance
# # import {
# #   to = aws_instance.sms_seller_connect_ec2
# #   id = "i-1234567890abcdef0"  # Replace with actual instance ID
# # }
# 
# # Example: Import existing S3 bucket
# # import {
# #   to = aws_s3_bucket.sms_seller_connect_bucket
# #   id = "sms-seller-connect-bucket"  # Replace with actual bucket name
# # }
# 
# # Example: Import existing Route53 hosted zone
# # import {
# #   to = aws_route53_zone.main
# #   id = "Z1234567890ABC"  # Replace with actual hosted zone ID
# # }
# 
# # Example: Import existing ALB
# # import {
# #   to = aws_lb.main
# #   id = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/sms-seller-connect/1234567890123456"
# # }
# 
# # Example: Import existing security group
# # import {
# #   to = aws_security_group.ec2_sg
# #   id = "sg-1234567890abcdef0"  # Replace with actual security group ID
# # }
# 
# ########################################
# # Instructions for Using Import Blocks
# ########################################
# 
# # 1. Identify existing resources:
# #    aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]'
# #    aws s3 ls
# #    aws route53 list-hosted-zones
# #    aws elbv2 describe-load-balancers
# 
# # 2. Uncomment and modify the relevant import blocks above
# 
# # 3. Run terraform plan to see what would be imported:
# #    terraform plan
# 
# # 4. Run terraform apply to import the resources:
# #    terraform apply
# 
# # 5. After successful import, you can comment out the import blocks
# #    (they're only needed once for the import operation)
# 
# ########################################
# # Terraform State Management
# ########################################
# 
# # If you need to remove resources from state without destroying them:
# # terraform state rm aws_instance.sms_seller_connect_ec2
# 
# # If you need to move resources in state:
# # terraform state mv aws_instance.old_name aws_instance.new_name
# 
# # If you need to show current state:
# # terraform state list
# # terraform state show aws_instance.sms_seller_connect_ec2 