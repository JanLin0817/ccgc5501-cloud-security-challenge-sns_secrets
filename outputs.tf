#############################################
# Outputs - Information for the Attacker
#############################################

#-----------------------------------------
# Starting Credentials (Attacker's Entry Point)
#-----------------------------------------

output "sns_user_access_key_id" {
  description = "Access Key ID for the sns_user (starting credentials)"
  value       = aws_iam_access_key.sns_user_key.id
}

output "sns_user_secret_access_key" {
  description = "Secret Access Key for the sns_user (starting credentials)"
  value       = aws_iam_access_key.sns_user_key.secret
  sensitive   = true
}

output "sns_user_arn" {
  description = "ARN of the sns_user"
  value       = aws_iam_user.sns_user.arn
}

#-----------------------------------------
# Scenario Information
#-----------------------------------------

output "scenario_id" {
  description = "Unique identifier for this scenario deployment"
  value       = local.cgid
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic (for admin reference)"
  value       = aws_sns_topic.public_topic.arn
}

#-----------------------------------------
# Solution Information (Admin Only)
#-----------------------------------------

output "api_gateway_url" {
  description = "[SOLUTION] Full API Gateway URL"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/user-data"
  sensitive   = true
}

output "api_key" {
  description = "[SOLUTION] API Key for accessing the API Gateway"
  value       = local.api_key
  sensitive   = true
}

#-----------------------------------------
# Quick Start Commands
#-----------------------------------------

output "quick_start_commands" {
  description = "Commands to get started with the scenario"
  value       = <<-EOT
    
    ============================================
    CloudGoat SNS Secrets - Quick Start
    ============================================
    
    1. Configure AWS CLI with the provided credentials:
       aws configure --profile sns-secrets
       
       Access Key ID: ${aws_iam_access_key.sns_user_key.id}
       Secret Key: (run 'terraform output -raw sns_user_secret_access_key')
       Region: ${var.aws_region}
    
    2. Verify access:
       aws sts get-caller-identity --profile sns-secrets
    
    3. Start enumerating:
       aws iam list-user-policies --user-name ${aws_iam_user.sns_user.name} --profile sns-secrets
    
    ============================================
    Goal: Find and retrieve the final flag!
    ============================================
    
  EOT
}

#-----------------------------------------
# Cleanup Command
#-----------------------------------------

output "destroy_command" {
  description = "Command to destroy all resources"
  value       = "terraform destroy -auto-approve"
}

#-----------------------------------------
# Verification Commands (Admin)
#-----------------------------------------

output "verification_commands" {
  description = "Commands to verify the scenario is working (admin only)"
  sensitive   = true
  value       = <<-EOT
    
    ============================================
    Admin Verification Commands
    ============================================
    
    # Test the Lambda function manually:
    aws lambda invoke --function-name ${aws_lambda_function.sns_publisher.function_name} \
        --region ${var.aws_region} /tmp/lambda-output.json && cat /tmp/lambda-output.json
    
    # Test the API Gateway with the correct key:
    curl -X GET '${aws_api_gateway_stage.prod.invoke_url}/user-data' \
        -H 'x-api-key: ${local.api_key}'
    
    # Check SNS topic subscriptions:
    aws sns list-subscriptions-by-topic \
        --topic-arn ${aws_sns_topic.public_topic.arn} \
        --region ${var.aws_region}
    
  EOT
}
