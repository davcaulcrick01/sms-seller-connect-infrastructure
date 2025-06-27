########################################
# Security Groups for Multi-App Architecture
########################################

# EC2 Security Group - Only accepts traffic from ALB
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${local.name_prefix}-ec2-"
  vpc_id      = data.aws_vpc.selected.id

  # HTTP from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "HTTP from ALB"
  }

  # HTTPS from ALB only (optional, if containers need HTTPS)
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "HTTPS from ALB"
  }

  # SSH from your office IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
    description = "SSH from admin"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ec2-sg"
      Type = "EC2 Security Group"
    }
  )
}