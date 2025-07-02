########################################
# Route53 DNS Configuration
########################################

# Get all hosted zones and filter for the correct one
data "aws_route53_zones" "all_zones" {}

# Use a local to find the zone ID that has the correct nameservers
locals {
  # The domain is currently using ns-735.awsdns-27.net as primary nameserver
  # Find the hosted zone that contains this nameserver
  matching_zones = [
    for zone_id in data.aws_route53_zones.all_zones.ids : zone_id
    if length(regexall("ns-735\\.awsdns-27\\.net", join(",", data.aws_route53_zone.all_zone_details[zone_id].name_servers))) > 0
  ]
  correct_zone_id = length(local.matching_zones) > 0 ? local.matching_zones[0] : ""
}

# Get details for all zones to check their nameservers
data "aws_route53_zone" "all_zone_details" {
  for_each = toset(data.aws_route53_zones.all_zones.ids)
  zone_id  = each.value
}

# Get the correct hosted zone details
data "aws_route53_zone" "main" {
  zone_id = local.correct_zone_id
}

# SMS Frontend - Main domain (sms.typerelations.com)
resource "aws_route53_record" "sms_frontend" {
  zone_id = local.correct_zone_id
  name    = var.sms_frontend_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}

# SMS API - Backend domain (api.sms.typerelations.com)
resource "aws_route53_record" "sms_api" {
  zone_id = local.correct_zone_id
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
  zone_id = local.correct_zone_id
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
  zone_id = local.correct_zone_id
  name    = var.carrental_api_domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.main]
}

########################################
# Route53 Outputs (for reference)
########################################

# Note: These are local to this file
# Main outputs.tf will expose the zone information at the module level 