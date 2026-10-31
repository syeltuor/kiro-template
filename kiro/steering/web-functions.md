---
inclusion: auto
name: web-functions
description: Lambda Web Functions (exception shape B) - one Lambda serves both the site and the API from a port-listening HTTP server such as Express, Hono, Fastify or Next.js on Lambda; AWS_LAMBDA_HTTP_ENDPOINT, aws lambda-web deploy, WebFunction endpoint, IamAuth, ApplicationManaged, single-function app, Web Functions cost or region. Use when the owner asks for shape B or a single Lambda web app.
---
<!-- kiro-template v2.0.0 -->

# Shape B: Lambda Web Functions (exception)

Lambda Web Functions (announced late 2026) run an ordinary port-listening Node.js
HTTP server (Express, Hono, Fastify, Next.js) with no adapter. Check the current
[Web Functions docs](https://docs.aws.amazon.com/lambda/latest/dg/web-functions.html)
first; facts below were true at time of writing.

- **Region.** At launch: a few regions incl. `eu-west-1` (Ireland), **not
  `eu-west-2`**. If London is still unsupported, `eu-west-1` is a deliberate
  deviation: record it in the design and get user approval before building.
- **Runtime.** The Node.js version Web Functions support (at launch one version,
  Arm64 only).
- **Server contract.** Listen on the `host:port` in `AWS_LAMBDA_HTTP_ENDPOINT`;
  set it yourself locally (e.g. `127.0.0.1:3000`).
- **Deploy.** `aws lambda-web deploy --name <name> --code <dir>` (revisions,
  endpoints, weighted traffic shifting) is for prototypes. Otherwise CloudFormation
  (`AWS::Lambda::WebFunction`, `WebFunctionEndpoint`, `WebFunctionRevision`;
  verify properties, they are new) via the project's deploy script.
- **Endpoint access.** The CLI default endpoint is public (`ApplicationManaged`).
  Behind CloudFront: `IamAuth` plus CloudFront OAC (origin type `lambda`) and a
  resource policy for your distribution only. The endpoint domain stays reachable
  but rejects unsigned requests. Verify against the docs.
- **CloudFront in front** for custom domain, TLS, security headers, WAF, static
  asset caching.
- **Throttling**: endpoint rate limit plus a cap on execution environments.
- **No VPC** (NAT/endpoints break the idle target). **Single-region**: don't
  enable multi-region latency routing.
- **Auth**: same decision table. Private data or writes: Cognito, tokens
  validated in the app (CloudFront forwards `Authorization` to an `IamAuth`
  endpoint; verify).

## Cost caveat

One environment serves many concurrent requests. Billing = requests + active CPU
+ memory **for as long as each environment exists** + data transfer. Environments
scale to zero, but Lambda may keep spare ones warm, so idle cost isn't
necessarily near zero: check Lambda pricing, estimate it in the design, confirm on
the real bill after a week.
