# Auth Option 1 — API Gateway API Key (canonical)

The recommended default. Authentication and rate limiting are handled by API
Gateway itself via an API Key + Usage Plan; your Lambda code stays clean.

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
curl -H "x-api-key: <KEY>" https://{{DOMAIN}}/admin/resource
```

## Frontend admin page pattern

```js
// Bootstrap the key from ?key= / ?apikey= / ?api_key=, store it, clean the URL.
const params = new URLSearchParams(location.search);
const urlKey = params.get('key') || params.get('apikey') || params.get('api_key');
if (urlKey) {
  localStorage.setItem('apiKey', urlKey);
  history.replaceState({}, '', location.pathname);   // strip key from the URL
}
const apiKey = localStorage.getItem('apiKey');

await fetch(`${BASE_URL}/admin/resource`, {
  headers: { 'x-api-key': apiKey, 'Content-Type': 'application/json' },
});
```

## Rotation

Regenerate the key in API Gateway (or recreate via the stack) and update clients.
Rotate periodically and immediately if a key is ever exposed.
