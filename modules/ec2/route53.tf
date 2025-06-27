########################################
# Route53 DNS Configuration
########################################

# Data source for existing hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_zone_name
  private_zone = false
}

# SMS Frontend - Main domain (sms.greyzoneapps.com)
resource "aws_route53_record" "sms_frontend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.sms_frontend_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}

# SMS API - Backend domain (api.sms.greyzoneapps.com)
resource "aws_route53_record" "sms_api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.sms_api_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}

# Optional: Car Rental Frontend (if you want to add it later)
resource "aws_route53_record" "carrental_frontend" {
  count   = var.enable_carrental_domain ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.carrental_frontend_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}

# Optional: Car Rental API (if you want to add it later)
resource "aws_route53_record" "carrental_api" {
  count   = var.enable_carrental_domain ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.carrental_api_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
} 