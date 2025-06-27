########################################
# Application Load Balancer for Multi-App Architecture
########################################

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "${local.name_prefix}-alb-"
  vpc_id      = data.aws_vpc.selected.id

  # HTTP inbound
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # HTTPS inbound
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  # All outbound
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
      Name = "${local.name_prefix}-alb-sg"
      Type = "ALB Security Group"
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [data.aws_subnet.public_subnet.id, data.aws_subnet.public_subnet_b.id]

  enable_deletion_protection = false

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-alb"
      Environment = var.environment
    }
  )
}

# Target Group for EC2 Instance
resource "aws_lb_target_group" "ec2_apps" {
  name     = "${local.name_prefix}-ec2-apps"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/alb-health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ec2-apps-tg"
    }
  )
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "ec2_apps" {
  target_group_arn = aws_lb_target_group.ec2_apps.arn
  target_id        = aws_instance.sms_seller_connect_ec2.id
  port             = 80
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_apps.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-https-listener"
    }
  )
}

# HTTP Listener (redirects to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-http-listener"
    }
  )
} 