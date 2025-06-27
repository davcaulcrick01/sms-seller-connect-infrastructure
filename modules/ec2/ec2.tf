########################################
# EC2 Instance for Multi-App Container Host
########################################

# Use existing car rental key pair
data "aws_key_pair" "existing_key" {
  key_name = "car_rental_pem"
}

# Note: EIP not needed since we use ALB for public access

# EC2 Instance
resource "aws_instance" "sms_seller_connect_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = data.aws_key_pair.existing_key.key_name
  subnet_id              = data.aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = data.aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true

    tags = merge(
      var.tags,
      {
        Name = "${local.name_prefix}-root-volume"
      }
    )
  }

  user_data = base64encode(templatefile("${path.module}/scripts/bootstrap.sh", {
    # AWS Configuration
    AWS_REGION     = data.aws_region.current.name
    AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    S3_BUCKET      = aws_s3_bucket.sms_seller_connect_bucket.bucket

    # Docker Images
    BACKEND_IMAGE  = var.backend_image
    FRONTEND_IMAGE = var.frontend_image

    # Domain Configuration
    SMS_API_DOMAIN      = var.sms_api_domain
    SMS_FRONTEND_DOMAIN = var.sms_frontend_domain

    # Database configuration
    DB_HOST     = var.db_host
    DB_PORT     = var.db_port
    DB_NAME     = var.db_name
    DB_USER     = var.db_user
    DB_PASSWORD = var.db_password

    # Application configuration
    SECRET_KEY          = var.flask_secret_key
    JWT_SECRET_KEY      = var.jwt_secret_key
    TWILIO_ACCOUNT_SID  = var.twilio_account_sid
    TWILIO_AUTH_TOKEN   = var.twilio_auth_token
    TWILIO_PHONE_NUMBER = var.twilio_phone_number
    OPENAI_API_KEY      = var.openai_api_key
    OPENAI_MODEL        = "gpt-4o"
    OPENAI_TEMPERATURE  = "0.3"

    # SendGrid configuration
    SENDGRID_API_KEY    = var.sendgrid_api_key
    SENDGRID_FROM_EMAIL = var.sendgrid_from_email

    # AWS application configuration
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    S3_BUCKET_NAME        = "grey-database-bucket"

    # Hot Lead Alert configuration
    HOT_LEAD_EMAIL_RECIPIENTS = "admin@greyzonesolutions.com"
    HOT_LEAD_SMS_RECIPIENTS   = "+14693785661"

    # Rate Limiting configuration
    RATE_LIMIT_PER_MINUTE = "60"
    RATE_LIMIT_BURST      = "10"

    # Session configuration
    SESSION_TIMEOUT_MINUTES = "60"
    REMEMBER_ME_DAYS        = "30"

    # File Upload configuration
    MAX_FILE_SIZE_MB   = "10"
    ALLOWED_FILE_TYPES = "pdf,jpg,jpeg,png,doc,docx,csv"

    # CloudWatch configuration
    CLOUDWATCH_LOG_GROUP  = "/aws/ec2/sms-seller-connect"
    CLOUDWATCH_LOG_STREAM = "application"

    # Environment
    ENVIRONMENT = var.environment
  }))

  tags = merge(
    var.tags,
    {
      Name = "${local.name_prefix}-ec2"
      Type = "Multi-App Container Host"
    }
  )

  depends_on = [
    aws_s3_object.docker_compose,
    aws_s3_object.nginx_config,
    aws_s3_object.env_template,
    aws_s3_object.maintenance_script,
    aws_s3_object.health_check_script,
    aws_s3_object.health_check_server,
    aws_s3_object.user_data_script
  ]
}

# Note: No EIP association needed since we use ALB for public access 