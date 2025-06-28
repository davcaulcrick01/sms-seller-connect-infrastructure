########################################
# IAM Role for EC2 Instance
########################################

# IAM Role for EC2 to access S3 and ECR
resource "aws_iam_role" "ec2_combined_role" {
  name = "ec2_combined_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "ec2_combined_role"
      Purpose     = "EC2 access to S3 and ECR"
      Environment = var.environment
    }
  )
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "ec2_s3_access_policy" {
  name        = "ec2-s3-access-policy"
  description = "Policy for EC2 to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.sms_seller_connect_bucket.arn,
          "${aws_s3_bucket.sms_seller_connect_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "ec2-s3-access-policy"
      Purpose     = "S3 access for EC2"
      Environment = var.environment
    }
  )
}

# IAM Policy for ECR Access
resource "aws_iam_policy" "ecr_access_policy" {
  name        = "ecr-access-policy"
  description = "Policy for EC2 to access ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "ecr-access-policy"
      Purpose     = "ECR access for EC2"
      Environment = var.environment
    }
  )
}

# Attach S3 policy to role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = aws_iam_policy.ec2_s3_access_policy.arn
}

# Attach ECR policy to role
resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = aws_iam_policy.ecr_access_policy.arn
}

# Attach SSM policy for Systems Manager
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_combined_role.name

  tags = merge(
    var.tags,
    {
      Name        = "ec2_instance_profile"
      Purpose     = "Instance profile for EC2"
      Environment = var.environment
    }
  )
}