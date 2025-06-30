########################################
# IAM Policy for EC2 to Access S3
########################################
# Reference existing policies using data sources
data "aws_iam_policy" "ec2_s3_access_policy" {
  name = "ec2-s3-access-policy"
}

data "aws_iam_policy" "ecr_policy" {
  name = "ecr-access-policy"
}
# Create the missing EC2 combined role
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

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Create the missing EC2 instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_combined_role.name

  lifecycle {
    prevent_destroy = true
  }
}

# Attach policies to role (only if not already attached)
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = data.aws_iam_policy.ec2_s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = aws_iam_role.ec2_combined_role.name
  policy_arn = data.aws_iam_policy.ecr_policy.arn
}

# Use existing instance profile for reference in EC2 configuration
data "aws_iam_instance_profile" "ec2_profile" {
  name       = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on = [aws_iam_instance_profile.ec2_instance_profile]
}
