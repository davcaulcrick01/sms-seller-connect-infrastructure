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

  # Port 8905 for direct API access (frontend requirement)
  ingress {
    from_port   = 8905
    to_port     = 8905
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Direct API access for frontend"
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

# Application Load Balancer #
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.public.ids

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

# Target Group for Port 8905 (Direct API Access)
resource "aws_lb_target_group" "api_direct" {
  name     = "${local.name_prefix}-api"
  port     = 8905
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.selected.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-api-direct-tg"
    }
  )
}

# Target Group Attachment for Port 8905
resource "aws_lb_target_group_attachment" "api_direct" {
  target_group_arn = aws_lb_target_group.api_direct.arn
  target_id        = aws_instance.sms_seller_connect_ec2.id
  port             = 8905
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

# Port 8905 Listener for Direct API Access
resource "aws_lb_listener" "api_direct" {
  load_balancer_arn = aws_lb.main.arn
  port              = "8905"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_direct.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-api-direct-listener"
    }
  )
} 