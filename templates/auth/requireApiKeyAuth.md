<!-- kiro-template v2.0.0 -->

> **Limited use, see security-standards v2.** API keys are for machine-to-machine
> callers, or public endpoints that need per-client usage-plan throttling (decision
> table row c). They are not user authentication: for any site that shows private
> data or has admin/write functions, use Cognito (`templates/cognito-stack.yaml`).

# API Gateway API Key + Usage Plan

Identification and per-client rate limiting are handled by API Gateway itself via
an API Key + Usage Plan; your Lambda code stays clean.

## CloudFormation (add to your API stack)

```yaml
Resources:
  # The REST API and its deployment/stage are assumed to exist as `RestApi`/`Stage`.

  ApiKey:
    Type: AWS::ApiGateway::ApiKey
    Properties:
      Name: !Sub "${AWS::StackName}-admin-key"
      Enabled: true

  UsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: !Sub "${AWS::StackName}-usage-plan"
      ApiStages:
        - ApiId: !Ref RestApi
          Stage: !Ref Stage
      Throttle:            # doubles as rate limiting
        BurstLimit: 100
        RateLimit: 50

  UsagePlanKey:
    Type: AWS::ApiGateway::UsagePlanKey
    Properties:
      KeyId: !Ref ApiKey
      KeyType: API_KEY
      UsagePlanId: !Ref UsagePlan

Outputs:
  ApiKeyId:
    Description: API Key ID (retrieve the value via the CLI, see below)
    Value: !Ref ApiKey
```

On protected methods, set `ApiKeyRequired: true` (leave public read methods
without it).

## Retrieving the key value (never hardcode it)

```bash
API_KEY_ID=$(aws cloudformation describe-stacks \
  --stack-name {{PROJECT_SLUG}}-api \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
  --output text --region eu-west-2)

aws apigateway get-api-key --api-key "$API_KEY_ID" --include-value \
  --region eu-west-2 --query 'value' --output text
```

## Client usage

```bash
curl -H "x-api-key: <KEY>" https://{{API_DOMAIN}}/resource
```

## Not for browser admin pages

v1 suggested storing an API key in `localStorage` for admin pages. In v2, a
browser admin surface uses Cognito instead: a key embedded in a web page is a
shared secret anyone with the page can copy.

## Rotation

Regenerate the key in API Gateway (or recreate via the stack) and update clients.
Rotate periodically and immediately if a key is ever exposed.
