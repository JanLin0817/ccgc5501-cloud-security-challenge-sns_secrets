#############################################
# CloudGoat SNS Secrets - Customizable Terraform
# 
# This Terraform configuration deploys a vulnerable-by-design
# AWS environment demonstrating SNS misconfiguration risks.
#
# WARNING: This creates intentionally vulnerable resources.
# Only deploy in isolated test accounts!
#############################################

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Environment = "cloudgoat"
      Scenario    = "sns_secrets"
      Stack       = var.cgid
      ManagedBy   = "terraform"
    }
  }
}

# Generate unique identifier for resources
resource "random_string" "cgid" {
  length  = 8
  special = false
  upper   = false
}

locals {
  cgid = var.cgid != "" ? var.cgid : "cgid${random_string.cgid.result}"
  
  # Customizable secret data - change these for your scenario
  api_key = var.api_key != "" ? var.api_key : random_string.api_key.result
  
  flag_data = {
    final_flag = var.custom_flag
    message    = "Access granted"
    user_data = {
      user_id  = "1337"
      username = var.secret_username
      email    = var.secret_email
      password = var.secret_password
    }
  }
}

resource "random_string" "api_key" {
  length  = 32
  special = false
  lower   = true
  upper   = false
}

#############################################
# IAM User - Starting Point for Attacker
#############################################

resource "aws_iam_user" "sns_user" {
  name = "cg-sns-user-${local.cgid}"
  path = "/"

  tags = {
    Description = "Low-privilege user for SNS secrets scenario"
  }
}

resource "aws_iam_access_key" "sns_user_key" {
  user = aws_iam_user.sns_user.name
}

# Inline policy for the SNS user
resource "aws_iam_user_policy" "sns_user_policy" {
  name   = "cg-sns-user-policy-${local.cgid}"
  user   = aws_iam_user.sns_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSAndIAMEnum"
        Effect = "Allow"
        Action = [
          # SNS permissions - allows subscribing to topics
          "sns:Subscribe",
          "sns:Receive",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTopics",
          "sns:GetTopicAttributes",
          
          # IAM enumeration permissions
          "iam:ListGroupsForUser",
          "iam:ListUserPolicies",
          "iam:GetUserPolicy",
          "iam:ListAttachedUserPolicies",
          
          # API Gateway enumeration
          "apigateway:GET"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAPIKeyEnumeration"
        Effect = "Deny"
        Action = "apigateway:GET"
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/apikeys",
          "arn:aws:apigateway:${var.aws_region}::/apikeys/*",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*/resources/*/methods/GET",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*/methods/GET",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*/resources/*/integration",
          "arn:aws:apigateway:${var.aws_region}::/restapis/*/integration"
        ]
      }
    ]
  })
}

#############################################
# SNS Topic - The Vulnerable Resource
#############################################

resource "aws_sns_topic" "public_topic" {
  name         = "public-topic-${local.cgid}"
  display_name = "CloudGoat SNS Secrets Topic"

  tags = {
    Description = "Misconfigured SNS topic that leaks API keys"
  }
}

# Overly permissive topic policy - THIS IS THE VULNERABILITY
resource "aws_sns_topic_policy" "public_topic_policy" {
  arn = aws_sns_topic.public_topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PublicTopicPolicy"
    Statement = [
      {
        Sid       = "AllowAnySubscription"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "SNS:Subscribe",
          "SNS:Receive"
        ]
        Resource = aws_sns_topic.public_topic.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AllowAccountPublish"
        Effect    = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.public_topic.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

#############################################
# API Gateway - Protected Resource
#############################################

resource "aws_api_gateway_rest_api" "secret_api" {
  name        = "cg-api-${local.cgid}"
  description = "API for demonstrating leaked API key scenario"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Description = "API Gateway protected by leaked API key"
  }
}

resource "aws_api_gateway_resource" "user_data" {
  rest_api_id = aws_api_gateway_rest_api.secret_api.id
  parent_id   = aws_api_gateway_rest_api.secret_api.root_resource_id
  path_part   = "user-data"
}

resource "aws_api_gateway_method" "get_user_data" {
  rest_api_id      = aws_api_gateway_rest_api.secret_api.id
  resource_id      = aws_api_gateway_resource.user_data.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "mock_integration" {
  rest_api_id             = aws_api_gateway_rest_api.secret_api.id
  resource_id             = aws_api_gateway_resource.user_data.id
  http_method             = aws_api_gateway_method.get_user_data.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.secret_api.id
  resource_id = aws_api_gateway_resource.user_data.id
  http_method = aws_api_gateway_method.get_user_data.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "mock_response" {
  rest_api_id = aws_api_gateway_rest_api.secret_api.id
  resource_id = aws_api_gateway_resource.user_data.id
  http_method = aws_api_gateway_method.get_user_data.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  response_templates = {
    "application/json" = jsonencode(local.flag_data)
  }

  depends_on = [aws_api_gateway_integration.mock_integration]
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.secret_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.user_data.id,
      aws_api_gateway_method.get_user_data.id,
      aws_api_gateway_integration.mock_integration.id,
      aws_api_gateway_integration_response.mock_response.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.get_user_data,
    aws_api_gateway_integration.mock_integration,
    aws_api_gateway_integration_response.mock_response,
  ]
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.secret_api.id
  stage_name    = "prod-${local.cgid}"

  tags = {
    Environment = "production"
  }
}

# API Key for accessing the API Gateway
resource "aws_api_gateway_api_key" "secret_key" {
  name    = "cg-api-key-${local.cgid}"
  enabled = true
  value   = local.api_key
}

resource "aws_api_gateway_usage_plan" "usage_plan" {
  name = "cg-usage-plan-${local.cgid}"

  api_stages {
    api_id = aws_api_gateway_rest_api.secret_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  quota_settings {
    limit  = 1000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }
}

resource "aws_api_gateway_usage_plan_key" "usage_plan_key" {
  key_id        = aws_api_gateway_api_key.secret_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan.id
}

#############################################
# Lambda Function - Publishes Secrets to SNS
#############################################

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_role" {
  name = "cg-lambda-sns-role-${local.cgid}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "cg-lambda-sns-policy-${local.cgid}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.public_topic.arn
      }
    ]
  })
}

# Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOF
import json
import boto3
import os

def lambda_handler(event, context):
    """
    This Lambda function simulates a misconfigured debug message
    that leaks an API key through SNS notifications.
    """
    sns = boto3.client('sns')
    
    topic_arn = os.environ['SNS_TOPIC_ARN']
    api_key = os.environ['API_KEY']
    api_endpoint = os.environ['API_ENDPOINT']
    
    # Simulated debug message - THIS IS THE VULNERABILITY
    debug_message = f"""
    [DEBUG] API Gateway Configuration
    ================================
    Endpoint: {api_endpoint}
    API Key: {api_key}
    
    This is an automated debug notification.
    Please contact the DevOps team if you're seeing this in production.
    """
    
    response = sns.publish(
        TopicArn=topic_arn,
        Message=debug_message,
        Subject='[CloudGoat] Debug: API Gateway Configuration'
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Debug notification sent',
            'messageId': response['MessageId']
        })
    }
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "sns_publisher" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cg-sns-publisher-${local.cgid}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.public_topic.arn
      API_KEY       = local.api_key
      API_ENDPOINT  = "${aws_api_gateway_stage.prod.invoke_url}/user-data"
    }
  }

  tags = {
    Description = "Lambda that leaks API key via SNS"
  }
}

# CloudWatch Event to trigger Lambda every 5 minutes
resource "aws_cloudwatch_event_rule" "every_five_minutes" {
  name                = "cg-sns-trigger-${local.cgid}"
  description         = "Trigger SNS publisher every ${var.publish_interval_minutes} minutes"
  schedule_expression = "rate(${var.publish_interval_minutes} minutes)"
  
  # Set to false by default - enable when ready
  is_enabled = var.enable_scheduled_publishing
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_five_minutes.name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.sns_publisher.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_publisher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_five_minutes.arn
}

#############################################
# Optional: VPC and EC2 Instance
# Uncomment if you want EC2 infrastructure
#############################################

# resource "aws_vpc" "main" {
#   cidr_block           = "10.0.0.0/16"
#   enable_dns_hostnames = true
#   enable_dns_support   = true
#
#   tags = {
#     Name = "cg-vpc-${local.cgid}"
#   }
# }
#
# resource "aws_subnet" "public" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.1.0/24"
#   availability_zone       = "${var.aws_region}a"
#   map_public_ip_on_launch = true
#
#   tags = {
#     Name = "cg-public-subnet-${local.cgid}"
#   }
# }
#
# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.main.id
#
#   tags = {
#     Name = "cg-igw-${local.cgid}"
#   }
# }
