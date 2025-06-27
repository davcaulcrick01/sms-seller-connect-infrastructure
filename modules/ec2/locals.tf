########################################
# Locals for EC2 Configuration
########################################
locals {
  ec2_name_prefix = "SMS-Seller-Connect"
  ami_id          = var.ami_id
  instance_type   = var.instance_type
  #ssh_cidr_block  = var.ssh_cidr_block

  # Dynamic name prefix based on project and environment
  name_prefix = "${var.project_name}-${var.environment}"
}

