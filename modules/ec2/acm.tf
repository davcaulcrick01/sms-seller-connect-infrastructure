########################################
# ACM Certificate for HTTPS
########################################

# Request ACM certificate
resource "aws_acm_certificate" "main" {
  domain_name = var.domain_zone_name
  subject_alternative_names = [
    "*.${var.domain_zone_name}",
    var.sms_frontend_domain,
    var.sms_api_domain
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name        = "${local.name_prefix}-ssl-certificate"
      Environment = var.environment
      Purpose     = "SSL Certificate for SMS Seller Connect"
    }
  )
}

# Route53 records for ACM certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# ACM certificate validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
} 