########################################
# CloudWatch Monitoring for Car Rental App
########################################

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "car_rental_app_logs" {
  name              = "/aws/ec2/car-rental-app"
  retention_in_days = 14

  tags = merge(
    var.tags,
    {
      Name        = "car-rental-app-logs"
      Environment = var.environment
      Purpose     = "Application Logs"
    }
  )
}

# CloudWatch Log Group for Docker Container Logs
resource "aws_cloudwatch_log_group" "docker_container_logs" {
  name              = "/aws/ec2/docker/car-rental"
  retention_in_days = 7

  tags = merge(
    var.tags,
    {
      Name        = "docker-container-logs"
      Environment = var.environment
      Purpose     = "Docker Container Logs"
    }
  )
}

# CloudWatch Log Group for System Logs
resource "aws_cloudwatch_log_group" "system_logs" {
  name              = "/aws/ec2/system/car-rental"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      Name        = "system-logs"
      Environment = var.environment
      Purpose     = "EC2 System Logs"
    }
  )
}

########################################
# CloudWatch Alarms for EC2 Instance
########################################

# High CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "car-rental-ec2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.car_rental_alerts.arn]
  ok_actions          = [aws_sns_topic.car_rental_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.sms_seller_connect_ec2.id
  }

  tags = var.tags
}

# High Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_high_memory" {
  alarm_name          = "car-rental-ec2-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ec2 memory utilization"
  alarm_actions       = [aws_sns_topic.car_rental_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.sms_seller_connect_ec2.id
  }

  tags = var.tags
}

# Low Disk Space Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_low_disk_space" {
  alarm_name          = "car-rental-ec2-low-disk-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DiskSpaceUtilization"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 disk space"
  alarm_actions       = [aws_sns_topic.car_rental_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.sms_seller_connect_ec2.id
    Filesystem = "/"
  }

  tags = var.tags
}

# Application Health Check Alarm
resource "aws_cloudwatch_metric_alarm" "app_health_check" {
  alarm_name          = "car-rental-app-health-check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_2XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors application health via ALB"
  alarm_actions       = [aws_sns_topic.car_rental_alerts.arn]

  dimensions = {
    LoadBalancer = var.alb_dns_name
  }

  tags = var.tags
}

########################################
# Custom Metrics for Car Rental Business
########################################

# Custom Metric for Failed Bookings
resource "aws_cloudwatch_log_metric_filter" "failed_bookings" {
  name           = "FailedBookings"
  log_group_name = aws_cloudwatch_log_group.car_rental_app_logs.name
  pattern        = "[timestamp, requestId, level=\"ERROR\", message=\"Booking failed*\"]"

  metric_transformation {
    name      = "FailedBookingCount"
    namespace = "CarRental/Business"
    value     = "1"
  }
}

# Custom Metric for Payment Failures
resource "aws_cloudwatch_log_metric_filter" "payment_failures" {
  name           = "PaymentFailures"
  log_group_name = aws_cloudwatch_log_group.car_rental_app_logs.name
  pattern        = "[timestamp, requestId, level=\"ERROR\", message=\"Payment failed*\"]"

  metric_transformation {
    name      = "PaymentFailureCount"
    namespace = "CarRental/Business"
    value     = "1"
  }
}

# Custom Metric for Database Connection Errors
resource "aws_cloudwatch_log_metric_filter" "database_errors" {
  name           = "DatabaseErrors"
  log_group_name = aws_cloudwatch_log_group.car_rental_app_logs.name
  pattern        = "[timestamp, requestId, level=\"ERROR\", message=\"Database*\"]"

  metric_transformation {
    name      = "DatabaseErrorCount"
    namespace = "CarRental/Technical"
    value     = "1"
  }
}

########################################
# Business Logic Alarms
########################################

# Failed Bookings Alarm
resource "aws_cloudwatch_metric_alarm" "failed_bookings_alarm" {
  alarm_name          = "car-rental-failed-bookings"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedBookingCount"
  namespace           = "CarRental/Business"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Alert when more than 3 bookings fail in 5 minutes"
  alarm_actions       = [aws_sns_topic.car_rental_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

# Payment Failures Alarm
resource "aws_cloudwatch_metric_alarm" "payment_failures_alarm" {
  alarm_name          = "car-rental-payment-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "PaymentFailureCount"
  namespace           = "CarRental/Business"
  period              = "300"
  statistic           = "Sum"
  threshold           = "2"
  alarm_description   = "Alert when more than 2 payments fail in 5 minutes"
  alarm_actions       = [aws_sns_topic.car_rental_alerts.arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

########################################
# SNS Topic for Alerts
########################################

# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "car_rental_alerts" {
  name = "car-rental-alerts"

  tags = merge(
    var.tags,
    {
      Name        = "car-rental-alerts"
      Environment = var.environment
      Purpose     = "CloudWatch Alerts"
    }
  )
}

# SNS Topic Subscription - Email
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.car_rental_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

########################################
# CloudWatch Dashboard
########################################

resource "aws_cloudwatch_dashboard" "car_rental_dashboard" {
  dashboard_name = "car-rental-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.sms_seller_connect_ec2.id],
            ["CWAgent", "MemoryUtilization", "InstanceId", aws_instance.sms_seller_connect_ec2.id],
            ["CWAgent", "DiskSpaceUtilization", "InstanceId", aws_instance.sms_seller_connect_ec2.id, "Filesystem", "/"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "EC2 System Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["CarRental/Business", "FailedBookingCount"],
            ["CarRental/Business", "PaymentFailureCount"],
            ["CarRental/Technical", "DatabaseErrorCount"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Business & Technical Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6

        properties = {
          query  = "SOURCE '${aws_cloudwatch_log_group.car_rental_app_logs.name}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region = var.region
          title  = "Recent Application Errors"
          view   = "table"
        }
      }
    ]
  })
}

########################################
# CloudWatch Agent Configuration
########################################

# IAM Role for CloudWatch Agent
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "CloudWatchAgentServerRole"

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
}

# Attach CloudWatch Agent Policy
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance Profile for CloudWatch Agent
resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "CloudWatchAgentServerProfile"
  role = aws_iam_role.cloudwatch_agent_role.name

  tags = var.tags
}

########################################
# CloudWatch Agent Configuration File
########################################

# Store CloudWatch Agent config in Parameter Store
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name = "/car-rental/cloudwatch-agent-config"
  type = "String"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path         = "/var/log/docker-container.log"
              log_group_name    = aws_cloudwatch_log_group.docker_container_logs.name
              log_stream_name   = "{instance_id}/docker"
              retention_in_days = 7
            },
            {
              file_path         = "/var/log/messages"
              log_group_name    = aws_cloudwatch_log_group.system_logs.name
              log_stream_name   = "{instance_id}/system"
              retention_in_days = 30
            }
          ]
        }
      }
    }
    metrics = {
      namespace = "CWAgent"
      metrics_collected = {
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_iowait",
            "cpu_usage_user",
            "cpu_usage_system"
          ]
          metrics_collection_interval = 60
          totalcpu                    = false
        }
        disk = {
          measurement = [
            "used_percent"
          ]
          metrics_collection_interval = 60
          resources = [
            "*"
          ]
        }
        diskio = {
          measurement = [
            "io_time",
            "read_bytes",
            "write_bytes",
            "reads",
            "writes"
          ]
          metrics_collection_interval = 60
          resources = [
            "*"
          ]
        }
        mem = {
          measurement = [
            "mem_used_percent"
          ]
          metrics_collection_interval = 60
        }
        netstat = {
          measurement = [
            "tcp_established",
            "tcp_time_wait"
          ]
          metrics_collection_interval = 60
        }
        swap = {
          measurement = [
            "swap_used_percent"
          ]
          metrics_collection_interval = 60
        }
      }
    }
  })

  tags = merge(
    var.tags,
    {
      Name        = "cloudwatch-agent-config"
      Environment = var.environment
      Purpose     = "CloudWatch Agent Configuration"
    }
  )
} 