########################################
# S3 Bucket for SMS Seller Connect Docker Compose files
########################################

resource "aws_s3_bucket" "sms_seller_connect_bucket" {
  bucket        = var.s3_bucket_name
  force_destroy = var.s3_force_destroy

  # Lifecycle rule to prevent accidental destruction
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Allow force_destroy changes for emergency cleanup if needed
      # force_destroy,
    ]
  }

  tags = merge(
    var.tags,
    {
      Name        = var.s3_bucket_name
      Environment = var.environment
      Purpose     = "SMS Seller Connect Docker Compose Storage"
    }
  )
}

# Configure bucket ACL
resource "aws_s3_bucket_acl" "sms_seller_connect_bucket_acl" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  acl    = var.bucket_acl

  depends_on = [aws_s3_bucket_ownership_controls.sms_seller_connect_bucket_acl_ownership]
}

# Bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "sms_seller_connect_bucket_acl_ownership" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable versioning for configuration files
resource "aws_s3_bucket_versioning" "sms_seller_connect_bucket_versioning" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "sms_seller_connect_bucket_encryption" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access (since we only need private access for EC2)
resource "aws_s3_bucket_public_access_block" "sms_seller_connect_bucket_pab" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

########################################
# Upload Docker Compose files to S3
########################################
resource "aws_s3_object" "docker_compose" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "docker-compose/docker-compose.yml"
  source = "${path.module}/config/docker-compose.yml"
  etag   = filemd5("${path.module}/config/docker-compose.yml")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-docker-compose"
      Environment = var.environment
      Purpose     = "Docker Compose Configuration"
    }
  )
}

resource "aws_s3_object" "nginx_config" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "nginx/nginx.conf"
  source = "${path.module}/config/nginx.conf"
  etag   = filemd5("${path.module}/config/nginx.conf")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-nginx-config"
      Environment = var.environment
      Purpose     = "Nginx Configuration"
    }
  )
}

resource "aws_s3_object" "env_template" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "docker-compose/.env.template"
  source = "${path.module}/config/.env.template"
  etag   = filemd5("${path.module}/config/.env.template")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-env-template"
      Environment = var.environment
      Purpose     = "Environment Template"
    }
  )
}

resource "aws_s3_object" "maintenance_script" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "scripts/maintenance.sh"
  source = "${path.module}/scripts/maintenance.sh"
  etag   = filemd5("${path.module}/scripts/maintenance.sh")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-maintenance-script"
      Environment = var.environment
      Purpose     = "Maintenance Script"
    }
  )
}

resource "aws_s3_object" "health_check_script" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "scripts/health-check.sh"
  source = "${path.module}/scripts/health-check.sh"
  etag   = filemd5("${path.module}/scripts/health-check.sh")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-health-check-script"
      Environment = var.environment
      Purpose     = "ALB Health Check Script"
    }
  )
}

resource "aws_s3_object" "health_check_server" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "scripts/health-check-server.py"
  source = "${path.module}/scripts/health-check-server.py"
  etag   = filemd5("${path.module}/scripts/health-check-server.py")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-health-check-server"
      Environment = var.environment
      Purpose     = "ALB Health Check HTTP Server"
    }
  )
}

resource "aws_s3_object" "user_data_script" {
  bucket = aws_s3_bucket.sms_seller_connect_bucket.id
  key    = "scripts/user_data.sh"
  source = "${path.module}/scripts/user_data.sh"
  etag   = filemd5("${path.module}/scripts/user_data.sh")

  tags = merge(
    var.tags,
    {
      Name        = "sms-seller-connect-user-data-script"
      Environment = var.environment
      Purpose     = "EC2 Bootstrap Script"
    }
  )
}
