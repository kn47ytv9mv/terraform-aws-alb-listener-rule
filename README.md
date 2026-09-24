# terraform-aws-alb-listener-rule

Terraform module for an Application Load Balancer listener rule — the
path-, host-, and header-based routing that decides which target group
a request reaches.

## Cost

Listener rules carry no charge. This module has no cost impact of its
own.

## Design

Without rules, a listener can only send every request to its single
default action. Rules are what make one load balancer serve several
services. Pair with
[`terraform-aws-alb-listener`](https://github.com/kn47ytv9mv/terraform-aws-alb-listener)
for the listener and
[`terraform-aws-alb-target-group`](https://github.com/kn47ytv9mv/terraform-aws-alb-target-group)
for the destinations. Rules apply only to Application Load Balancers —
a Network Load Balancer has no concept of them.

One rule per module call, because a listener commonly has many and each
is independently prioritised and owned.

### Priority is the whole game

Rules evaluate in ascending `priority`, and **the first rule whose
conditions all match wins — no later rule is considered.** A broad rule
at a low priority silently shadows every specific rule beneath it, and
nothing reports this: the shadowed rule simply never fires. Leaving
`priority` null has AWS assign the next available number, which makes
ordering implicit and nearly impossible to reason about once there is
more than one rule. Set it explicitly, and leave gaps between values so
a rule can be inserted later without renumbering.

### Conditions

**At least one condition is required** — AWS rejects a rule with none,
and a rule matching everything is precisely what the listener's own
default action already does. This module enforces it at plan time.

Every condition variable supplied becomes its own condition block, and
**all of them must match** for the rule to fire. Two path patterns in
one list are an OR; a path pattern plus a host header is an AND.

`path_patterns` matching is case-sensitive and must cover the whole
path: `/api` matches only that exact path, while `/api/*` matches
everything beneath it but not `/api` itself. Supply both when you mean
both — this catches people out constantly.

`source_ips` matches the address the load balancer actually sees, which
behind CloudFront or any proxy is the proxy's address, not the client's.
Match on an `X-Forwarded-For` header condition instead in that case.

### Actions

`forward` to a single `target_group_arn`, or to weighted `target_groups`
for a blue/green or canary rollout. When splitting traffic, set
`stickiness_duration` as well — without it a client can land on a
different group on every request, which defeats a canary that needs
consistent sessions.

`redirect` defaults each field to the incoming request's own value, so
an HTTP-to-HTTPS redirect is just `protocol` and `port`. `fixed-response`
answers directly with no backend at all, which is how a maintenance page
or an outright deny is served.

### Deliberately not covered

`authenticate-oidc` and `authenticate-cognito` actions, JWT validation,
and host/URL rewrite transforms are not exposed. Each carries
significant nested surface for a feature most rules do not use, and the
authentication actions in particular need a matching identity provider
this module cannot create.

## Usage

```hcl
module "api_rule" {
  source = "kn47ytv9mv/alb-listener-rule/aws"

  listener_arn     = module.listener.arn
  priority         = 100
  target_group_arn = module.api_target_group.arn

  path_patterns = ["/api/*"]
}
```

Or directly from this repository, splitting traffic for a canary:

```hcl
module "canary_rule" {
  source = "github.com/kn47ytv9mv/terraform-aws-alb-listener-rule"

  listener_arn = module.listener.arn
  priority     = 200

  target_groups = [
    { arn = module.blue.arn, weight = 90 },
    { arn = module.green.arn, weight = 10 },
  ]

  stickiness_duration = 3600
  host_headers        = ["app.example.com"]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9 |
| aws | ~> 6.61 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| listener_arn | ARN of the listener this rule attaches to, from `terraform-aws-alb-listener`. | `null` | no |
| priority | Evaluation order, 1 to 50000, lowest first. The first matching rule wins and no later rule is considered. | `null` | no |
| action_type | `'forward'`, `'redirect'`, or `'fixed-response'`. | `"forward"` | no |
| target_group_arn | ARN of the target group to forward to. Mutually exclusive with `target_groups`. | `null` | no |
| target_groups | Weighted target groups to split traffic across, for a canary or blue/green rollout. | `[]` | no |
| stickiness_duration | Seconds a client stays pinned to one weighted group, 1 to 604800. | `null` | no |
| redirect | Where to redirect, when `action_type` is `'redirect'`. Unset fields default to the incoming request's own values. | `null` | no |
| fixed_response | The response to return directly, when `action_type` is `'fixed-response'`. | `null` | no |
| path_patterns | Request paths this rule matches. Case-sensitive, and must cover the whole path. | `[]` | no |
| host_headers | Host headers this rule matches. Matched case-insensitively. | `[]` | no |
| http_request_methods | HTTP methods this rule matches. AWS expects them uppercase. | `[]` | no |
| source_ips | Client CIDR blocks. Matches the address the load balancer sees, not the end client behind a proxy. | `[]` | no |
| http_headers | Arbitrary request headers to match, each a name and its values. | `[]` | no |
| query_strings | Query string key/value pairs to match. A null key matches the value under any key. | `[]` | no |
| tags | A map of tags to assign to the rule. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the rule. |
| arn | The ARN of the rule. |
| priority | The rule's evaluation priority, including one AWS assigned when `priority` was left null. |

## License

MIT — see [LICENSE.md](LICENSE.md).
