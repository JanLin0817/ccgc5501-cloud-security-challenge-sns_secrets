# CloudGoat SNS Secrets - Customizable Terraform

A customizable Terraform deployment for the SNS Secrets vulnerable-by-design AWS scenario. This scenario demonstrates the risks of misconfigured SNS topics and leaked API credentials.

## ⚠️ Warning

**This creates intentionally vulnerable AWS resources!**

- Only deploy in isolated test/training AWS accounts
- Never deploy in production environments
- Destroy resources promptly after use to avoid charges
- Monitor for unauthorized access

## Scenario Overview

### Attack Path

```
┌─────────────────────┐
│   Start: IAM User   │
│   (Limited Access)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Enumerate IAM      │
│  Permissions        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Discover SNS       │
│  Topics             │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Subscribe to       │
│  SNS Topic (Email)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Receive Leaked     │
│  API Key via Email  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Enumerate API      │
│  Gateway Endpoints  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Invoke API with    │
│  Leaked Key         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  🚩 CAPTURE FLAG!   │
└─────────────────────┘
```

### Key Vulnerabilities

1. **Overly Permissive SNS Topic Policy** - Allows any authenticated user to subscribe
2. **Secrets Leaked via SNS** - API keys sent in debug messages
3. **Insufficient IAM Restrictions** - User can enumerate sensitive resources

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with admin credentials
- An AWS account (preferably isolated for testing)

## Quick Start

### 1. Deploy

```bash
# Navigate to the terraform directory
cd sns_secrets_terraform

# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the scenario
terraform apply
```

### 2. Get Starting Credentials

```bash
# View access key ID
terraform output sns_user_access_key_id

# View secret key (sensitive)
terraform output -raw sns_user_secret_access_key
```

### 3. Start the Challenge

Configure AWS CLI with the scenario credentials:

```bash
aws configure --profile sns-secrets
# Enter the credentials from terraform output
```

### 4. Cleanup

```bash
terraform destroy -auto-approve
```

## Architecture Diagram

```
                                    ┌──────────────────┐
                                    │   CloudWatch     │
                                    │   Events Rule    │
                                    │  (every 5 min)   │
                                    └────────┬─────────┘
                                             │
                                             ▼
┌─────────────────┐              ┌──────────────────┐
│   SNS Topic     │◄─────────────│  Lambda Function │
│  (Public Sub)   │   Publishes  │  (Publisher)     │
└────────┬────────┘   API Key    └──────────────────┘
         │
         │ Email
         ▼
┌─────────────────┐              ┌──────────────────┐
│   Attacker      │─────────────►│  API Gateway     │
│   (sns_user)    │  Uses Key    │  (Protected)     │
└─────────────────┘              └────────┬─────────┘
                                          │
                                          ▼
                                 ┌──────────────────┐
                                 │   🚩 FLAG        │
                                 └──────────────────┘
```

## Security Lessons

This scenario teaches:

1. **Principle of Least Privilege** - Don't grant broad SNS subscription permissions
2. **Secret Management** - Never send secrets through messaging services
3. **Defense in Depth** - Multiple layers of protection for APIs
4. **Monitoring** - Detect unusual subscription patterns

## License

MIT License - Use for educational purposes only.