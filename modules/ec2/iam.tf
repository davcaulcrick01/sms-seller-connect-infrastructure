########################################
# IAM Policy for EC2 to Access S3
########################################
# Reference existing policies and roles using data sources
data "aws_iam_policy" "ec2_s3_access_policy" {
  name = "ec2-s3-access-policy"
}

data "aws_iam_policy" "ecr_policy" {
  name = "ecr-access-policy"
}

# Use existing instance profile (this exists)
data "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_combined_profile"
}

# Get the role from the instance profile
data "aws_iam_role" "ec2_combined_role" {
  name = data.aws_iam_instance_profile.ec2_profile.roles[0]
}

# Attach policies to role (only if not already attached)
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = data.aws_iam_role.ec2_combined_role.name
  policy_arn = data.aws_iam_policy.ec2_s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecr_policy_attachment" {
  role       = data.aws_iam_role.ec2_combined_role.name
  policy_arn = data.aws_iam_policy.ecr_policy.arn
}