# Global Behavior & Language Policy
- **Output Language**: English ONLY. (Mandatory for all responses and internal reasoning).
- **Token Optimization**: Eliminate all greetings, apologies, and conversational fluff. Start responses directly with technical information.
- **Priority**: Maintain 100% fidelity to the technical constraints defined in the original rules below.

# AWS API Gateway Patterns

## Purpose
AWS API Gateway is a fully managed service for creating, publishing, and managing APIs at scale. These patterns define mandatory configuration standards for AWS API Gateway deployments. Every rule below is **mandatory** — not aspirational.

## AWSGW-01: REST API vs HTTP API Decision Matrix

| Criteria | REST API | HTTP API |
|----------|----------|----------|
| **Cost** | Higher ($3.50/million requests) | Lower ($1.00/million requests) |
| **Latency** | Higher (~30ms overhead) | Lower (~10ms overhead) |
| **Lambda integration** | Proxy and non-proxy | Proxy only (payload format 2.0) |
| **Usage plans / API keys** | Yes (built-in) | No (use Lambda authorizer or external) |
| **Request validation** | Yes (JSON schema) | No |
| **Request/Response transformation** | Yes (VTL mapping templates) | No |
| **WAF integration** | Yes | No |
| **Resource policies** | Yes | No |
| **Caching** | Yes (built-in) | No (use CloudFront) |
| **Private integrations (VPC Link)** | Yes (NLB-based) | Yes (ALB, NLB, Cloud Map) |
| **JWT authorizer** | No (use Lambda authorizer) | Yes (built-in) |
| **OIDC / OAuth2** | No (use Cognito or Lambda) | Yes (built-in) |
| **Mutual TLS** | Yes | Yes |

**Decision rule:**
- Use **HTTP API** when: cost and latency matter, JWT/OIDC auth is sufficient, no request transformation or caching needed
- Use **REST API** when: you need usage plans, API keys, request validation, WAF, request/response transformation, or caching
- NEVER use REST API just because "it has more features" — pay for what you use

## AWSGW-02: Lambda Integration

### Proxy Integration (Recommended Default)

```yaml
# SAM / CloudFormation
Resources:
  UsersFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: index.handler
      Runtime: nodejs20.x
      MemorySize: 256
      Timeout: 29
      Events:
        GetUsers:
          Type: HttpApi
          Properties:
            Path: /api/v1/users
            Method: GET
            ApiId: !Ref HttpApi
```

**Proxy integration passes the entire request to Lambda and expects a specific response format:**

```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json",
    "X-Request-Id": "abc-123"
  },
  "body": "{\"users\": []}",
  "isBase64Encoded": false
}
```

### Non-Proxy Integration (REST API Only)

**Use when the gateway must transform requests/responses using VTL mapping templates.**

```yaml
Resources:
  UsersMethod:
    Type: AWS::ApiGateway::Method
    Properties:
      RestApiId: !Ref RestApi
      ResourceId: !Ref UsersResource
      HttpMethod: GET
      AuthorizationType: COGNITO_USER_POOLS
      AuthorizerId: !Ref CognitoAuthorizer
      Integration:
        Type: AWS
        IntegrationHttpMethod: POST
        Uri: !Sub "arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${UsersFunction.Arn}/invocations"
        RequestTemplates:
          application/json: |
            {
              "userId": "$input.params('userId')",
              "requestContext": {
                "requestId": "$context.requestId",
                "identity": {
                  "sub": "$context.authorizer.claims.sub"
                }
              }
            }
        IntegrationResponses:
          - StatusCode: "200"
            ResponseTemplates:
              application/json: |
                #set($body = $util.parseJson($input.body))
                {
                  "data": $input.json('$.users'),
                  "meta": {
                    "requestId": "$context.requestId"
                  }
                }
```

**Rules:**
- Use **proxy integration** as the default — it is simpler and keeps transformation logic in application code
- Use **non-proxy integration** only when you need gateway-level request/response transformation that cannot be changed in application code
- Lambda timeout MUST be less than API Gateway timeout (29s for REST API, 30s for HTTP API)
- Lambda function MUST return the exact response format expected by the integration type — malformed responses cause `502 Bad Gateway`
- NEVER use synchronous Lambda integration for long-running operations — use async invocation with a callback or Step Functions

## AWSGW-03: Usage Plans and API Keys (REST API)

```yaml
Resources:
  UsagePlan:
    Type: AWS::ApiGateway::UsagePlan
    Properties:
      UsagePlanName: partner-tier
      Description: "Partner API access tier"
      ApiStages:
        - ApiId: !Ref RestApi
          Stage: prod
      Throttle:
        BurstLimit: 200
        RateLimit: 100
      Quota:
        Limit: 50000
        Period: MONTH

  PartnerApiKey:
    Type: AWS::ApiGateway::ApiKey
    Properties:
      Name: partner-acme-corp
      Enabled: true

  UsagePlanKey:
    Type: AWS::ApiGateway::UsagePlanKey
    Properties:
      KeyId: !Ref PartnerApiKey
      KeyType: API_KEY
      UsagePlanId: !Ref UsagePlan
```

**Usage plan tiers:**

| Tier | Rate (req/s) | Burst | Monthly Quota | Use Case |
|------|:-----------:|:-----:|:------------:|----------|
| Free | 10 | 20 | 10,000 | Trial access, developer sandbox |
| Standard | 50 | 100 | 100,000 | Production integration |
| Partner | 100 | 200 | 500,000 | Strategic partner integration |
| Enterprise | 500 | 1000 | Unlimited | Enterprise contract |

**Rules:**
- API keys are for identification and throttling, NOT for authentication — always combine with an authorizer
- NEVER embed API keys in client-side code (mobile apps, SPAs) — use OAuth2 tokens instead
- Rotate API keys on a regular schedule (quarterly minimum)
- Monitor usage plan consumption and alert at 80% quota utilization
- `BurstLimit` MUST be at least 2x `RateLimit` to handle legitimate traffic spikes

## AWSGW-04: Custom Domain Setup

```yaml
Resources:
  CustomDomain:
    Type: AWS::ApiGatewayV2::DomainName
    Properties:
      DomainName: api.example.com
      DomainNameConfigurations:
        - CertificateArn: !Ref AcmCertificate
          EndpointType: REGIONAL
          SecurityPolicy: TLS_1_2

  ApiMapping:
    Type: AWS::ApiGatewayV2::ApiMapping
    Properties:
      ApiId: !Ref HttpApi
      DomainName: !Ref CustomDomain
      Stage: prod
      ApiMappingKey: v1

  DnsRecord:
    Type: AWS::Route53::RecordSet
    Properties:
      HostedZoneId: !Ref HostedZone
      Name: api.example.com
      Type: A
      AliasTarget:
        DNSName: !GetAtt CustomDomain.RegionalDomainName
        HostedZoneId: !GetAtt CustomDomain.RegionalHostedZoneId
```

**Rules:**
- ALWAYS use custom domains — never expose the auto-generated `execute-api` URL to clients
- TLS security policy MUST be `TLS_1_2` minimum — never allow TLS 1.0 or 1.1
- ACM certificate MUST be in the same region as the API (for regional endpoints) or `us-east-1` (for edge-optimized)
- Use `ApiMappingKey` to version APIs under the same domain (`api.example.com/v1`, `api.example.com/v2`)
- Set up DNS failover if using multi-region deployment

## AWSGW-05: WAF Integration (REST API)

```yaml
Resources:
  ApiWafAcl:
    Type: AWS::WAFv2::WebACL
    Properties:
      Name: api-gateway-waf
      Scope: REGIONAL
      DefaultAction:
        Allow: {}
      Rules:
        - Name: rate-limit-rule
          Priority: 1
          Action:
            Block: {}
          Statement:
            RateBasedStatement:
              Limit: 2000
              AggregateKeyType: IP
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: rate-limit-rule
        - Name: aws-managed-common-rules
          Priority: 2
          OverrideAction:
            None: {}
          Statement:
            ManagedRuleGroupStatement:
              VendorName: AWS
              Name: AWSManagedRulesCommonRuleSet
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: common-rules
        - Name: aws-managed-sqli-rules
          Priority: 3
          OverrideAction:
            None: {}
          Statement:
            ManagedRuleGroupStatement:
              VendorName: AWS
              Name: AWSManagedRulesSQLiRuleSet
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: sqli-rules
        - Name: aws-managed-bad-inputs
          Priority: 4
          OverrideAction:
            None: {}
          Statement:
            ManagedRuleGroupStatement:
              VendorName: AWS
              Name: AWSManagedRulesKnownBadInputsRuleSet
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: bad-inputs
      VisibilityConfig:
        SampledRequestsEnabled: true
        CloudWatchMetricsEnabled: true
        MetricName: api-gateway-waf

  WafAssociation:
    Type: AWS::WAFv2::WebACLAssociation
    Properties:
      ResourceArn: !Sub "arn:aws:apigateway:${AWS::Region}::/restapis/${RestApi}/stages/prod"
      WebACLArn: !GetAtt ApiWafAcl.Arn
```

**Mandatory WAF rules (minimum baseline):**

| Rule | Purpose | Priority |
|------|---------|:--------:|
| Rate limiting (IP-based) | DDoS protection | 1 |
| AWSManagedRulesCommonRuleSet | OWASP Top 10 protections | 2 |
| AWSManagedRulesSQLiRuleSet | SQL injection protection | 3 |
| AWSManagedRulesKnownBadInputsRuleSet | Log4j, bad bots, known exploits | 4 |

**Rules:**
- WAF MUST be attached to every production REST API — no exceptions
- Enable `SampledRequestsEnabled` and `CloudWatchMetricsEnabled` on all rules
- Start with `Count` mode for new rules, switch to `Block` after validating no false positives
- Rate limit threshold MUST be tuned based on actual traffic patterns — 2000 requests per 5 minutes per IP is a starting point

## AWSGW-06: Request/Response Models (REST API)

```yaml
Resources:
  CreateUserModel:
    Type: AWS::ApiGateway::Model
    Properties:
      RestApiId: !Ref RestApi
      ContentType: application/json
      Name: CreateUserRequest
      Schema:
        $schema: "http://json-schema.org/draft-04/schema#"
        type: object
        required:
          - email
          - name
        properties:
          email:
            type: string
            format: email
            maxLength: 255
          name:
            type: string
            minLength: 1
            maxLength: 100
          role:
            type: string
            enum:
              - admin
              - member
              - viewer

  CreateUserValidator:
    Type: AWS::ApiGateway::RequestValidator
    Properties:
      RestApiId: !Ref RestApi
      Name: validate-body
      ValidateRequestBody: true
      ValidateRequestParameters: true
```

**Rules:**
- Define request models for all `POST` and `PUT` endpoints — reject malformed requests at the gateway
- Use `ValidateRequestBody: true` AND `ValidateRequestParameters: true`
- Models MUST enforce `required` fields, `maxLength`, and `enum` constraints at minimum
- Validation errors return `400` with a structured error message — override the default gateway response for readability
- Models are defined per method — do not share models across unrelated endpoints

## AWSGW-07: Stage Variables

```yaml
Resources:
  RestApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: my-api

  ProdStage:
    Type: AWS::ApiGateway::Stage
    Properties:
      RestApiId: !Ref RestApi
      StageName: prod
      Variables:
        lambdaAlias: prod
        tableName: users-prod
        logLevel: ERROR

  StagingStage:
    Type: AWS::ApiGateway::Stage
    Properties:
      RestApiId: !Ref RestApi
      StageName: staging
      Variables:
        lambdaAlias: staging
        tableName: users-staging
        logLevel: DEBUG
```

**Reference stage variables in integrations:**
- Lambda function ARN: `arn:aws:lambda:region:account:function:my-func:${stageVariables.lambdaAlias}`
- Mapping templates: `$stageVariables.tableName`

**Rules:**
- Use stage variables to differentiate environments — NEVER hardcode environment-specific values in the API definition
- Stage variables MUST NOT contain secrets — use AWS Secrets Manager or SSM Parameter Store for sensitive values
- Lambda aliases (`prod`, `staging`) MUST point to specific published versions, not `$LATEST`
- Enable access logging on all stages with structured JSON format
- Enable CloudWatch metrics and X-Ray tracing on production stages

## Anti-Patterns (FORBIDDEN)

- Exposing the auto-generated `execute-api` URL to clients instead of a custom domain
- Using REST API when HTTP API meets all requirements (wasting cost and adding latency)
- Setting Lambda timeout equal to or greater than API Gateway timeout
- Using API keys as the sole authentication mechanism
- Deploying REST API to production without WAF
- Using `$LATEST` Lambda alias in production stage variables
- Hardcoding environment-specific values in the API definition instead of stage variables
- Skipping request model validation on write endpoints
- Allowing TLS 1.0 or 1.1 on custom domains
- Synchronous Lambda integration for operations exceeding 29 seconds
