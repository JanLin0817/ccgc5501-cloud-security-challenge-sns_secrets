#############################################
# Variables for SNS Secrets Scenario
# 
# Customize these values for your deployment
#############################################

#-----------------------------------------
# AWS Configuration
#-----------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for deployment"
  type        = string
  default     = "default"
}

variable "cgid" {
  description = "Unique identifier for CloudGoat resources (auto-generated if empty)"
  type        = string
  default     = ""
}

#-----------------------------------------
# Scenario Customization
#-----------------------------------------

variable "custom_flag" {
  description = "Custom flag message for successful completion"
  type        = string
  default     = "FLAG{SNS_S3cr3ts_ar3_FUN}"
}

variable "api_key" {
  description = "Custom API key (auto-generated if empty)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "secret_username" {
  description = "Username revealed in the final flag"
  type        = string
  default     = "SuperAdmin"
}

variable "secret_email" {
  description = "Email revealed in the final flag"
  type        = string
  default     = "SuperAdmin@notarealemail.com"
}

variable "secret_password" {
  description = "Password revealed in the final flag"
  type        = string
  default     = "p@ssw0rd123"
  sensitive   = true
}

#-----------------------------------------
# SNS Publishing Configuration
#-----------------------------------------

variable "enable_scheduled_publishing" {
  description = "Enable automatic SNS message publishing (set to true when ready)"
  type        = bool
  default     = true
}

variable "publish_interval_minutes" {
  description = "How often to publish the debug message to SNS (in minutes)"
  type        = number
  default     = 5

  validation {
    condition     = var.publish_interval_minutes >= 1 && var.publish_interval_minutes <= 60
    error_message = "Publish interval must be between 1 and 60 minutes."
  }
}

#-----------------------------------------
# IAM Policy Customization
#-----------------------------------------

variable "allow_iam_simulation" {
  description = "Allow the sns_user to use iam:SimulatePrincipalPolicy"
  type        = bool
  default     = false
}

variable "additional_sns_permissions" {
  description = "Additional SNS permissions to grant to sns_user"
  type        = list(string)
  default     = []
  
  # Example: ["sns:Publish", "sns:Unsubscribe"]
}

#-----------------------------------------
# Difficulty Settings
#-----------------------------------------

variable "difficulty" {
  description = "Scenario difficulty: easy, medium, hard"
  type        = string
  default     = "easy"

  validation {
    condition     = contains(["easy", "medium", "hard"], var.difficulty)
    error_message = "Difficulty must be 'easy', 'medium', or 'hard'."
  }
}

# Difficulty affects:
# - easy: API key sent in plain text, frequent publishing
# - medium: API key slightly obfuscated, less frequent publishing  
# - hard: API key encoded, requires additional enumeration

variable "obfuscate_api_key" {
  description = "Obfuscate the API key in SNS messages (for harder difficulty)"
  type        = bool
  default     = false
}

#-----------------------------------------
# Networking (Optional)
#-----------------------------------------

variable "create_vpc" {
  description = "Create VPC infrastructure (for EC2-based scenarios)"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

#-----------------------------------------
# Monitoring & Logging
#-----------------------------------------

variable "enable_cloudtrail" {
  description = "Enable CloudTrail logging for the scenario"
  type        = bool
  default     = false
}

variable "enable_api_gateway_logging" {
  description = "Enable API Gateway access logging"
  type        = bool
  default     = false
}

#-----------------------------------------
# Cleanup Settings
#-----------------------------------------

variable "auto_destroy_after_hours" {
  description = "Auto-destroy resources after N hours (0 = disabled)"
  type        = number
  default     = 0
}
