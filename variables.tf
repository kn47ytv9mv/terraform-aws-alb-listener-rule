variable "listener_arn" {
  default     = null
  description = "ARN of the listener this rule attaches to, from terraform-aws-alb-listener. Rules only apply to Application Load Balancer listeners — a Network Load Balancer has no concept of them."
}

variable "priority" {
  default     = null
  description = "Evaluation order, 1 to 50000, lowest first. The first rule whose conditions all match wins, and no later rule is considered — so a broad rule placed at a low priority silently shadows every specific rule below it. If null, AWS assigns the next available priority, which makes ordering implicit and hard to reason about; set it explicitly for anything beyond a single rule."

  validation {
    condition     = var.priority == null || (var.priority >= 1 && var.priority <= 50000)
    error_message = "priority must be between 1 and 50000."
  }
}

variable "action_type" {
  default     = "forward"
  description = "What the rule does with a matching request: 'forward' to a target group, 'redirect' to another URL, or 'fixed-response' to answer directly without a backend."

  validation {
    condition     = contains(["forward", "redirect", "fixed-response"], var.action_type)
    error_message = "action_type must be one of 'forward', 'redirect', or 'fixed-response'."
  }
}

variable "target_group_arn" {
  default     = null
  description = "ARN of the target group to forward to, from terraform-aws-alb-target-group. Used when action_type is 'forward' and target_groups is not set. Required for a forward rule unless target_groups supplies the destinations instead."
}

variable "target_groups" {
  default     = []
  description = "Weighted target groups to split matching traffic across, for a blue/green or canary rollout. Each entry's weight is relative to the others, so two groups weighted 90 and 10 send a tenth of traffic to the second. Mutually exclusive with target_group_arn."
  type = list(object({
    arn    = string
    weight = optional(number)
  }))

  validation {
    condition     = length(var.target_groups) == 0 || var.target_group_arn == null
    error_message = "target_group_arn forwards to one group and target_groups splits across several; at most one may be set."
  }

  validation {
    condition     = var.action_type != "forward" || var.target_group_arn != null || length(var.target_groups) > 0
    error_message = "A 'forward' rule needs either target_group_arn or a non-empty target_groups."
  }
}

variable "stickiness_duration" {
  default     = null
  description = "Seconds a client stays pinned to whichever weighted target group it first reached, 1 to 604800. Only meaningful alongside target_groups — without it a client can be sent to a different group on every request, which defeats a canary that needs consistent sessions. If null, no stickiness is applied."
}

variable "redirect" {
  default     = null
  description = "Where to redirect a matching request, when action_type is 'redirect'. Every field except status_code is optional and defaults to the incoming request's own value, so setting only protocol and port is how an HTTP-to-HTTPS redirect is written. status_code is 'HTTP_301' (permanent) or 'HTTP_302' (temporary). The tokens '#{host}', '#{path}', '#{port}', '#{protocol}', and '#{query}' interpolate parts of the original request."
  type = object({
    status_code = optional(string, "HTTP_301")
    protocol    = optional(string)
    port        = optional(string)
    host        = optional(string)
    path        = optional(string)
    query       = optional(string)
  })

  validation {
    condition     = var.redirect == null || contains(["HTTP_301", "HTTP_302"], var.redirect.status_code)
    error_message = "A redirect's status_code must be 'HTTP_301' or 'HTTP_302'."
  }
}

variable "fixed_response" {
  default     = null
  description = "The response to return directly, when action_type is 'fixed-response'. Useful for serving a maintenance page, or for denying a path outright without involving a backend at all."
  type = object({
    content_type = optional(string, "text/plain")
    status_code  = optional(string, "200")
    message_body = optional(string)
  })

  validation {
    condition     = var.fixed_response == null || contains(["text/plain", "text/css", "text/html", "application/javascript", "application/json"], var.fixed_response.content_type)
    error_message = "A fixed response's content_type must be one of 'text/plain', 'text/css', 'text/html', 'application/javascript', or 'application/json'."
  }
}

variable "path_patterns" {
  default     = []
  description = "Request paths this rule matches (e.g. ['/api/*']). Matching is case-sensitive, and the pattern must cover the whole path — '/api' matches only that exact path, while '/api/*' matches everything beneath it but not '/api' itself. Supply both when you mean both."

  validation {
    condition     = length(var.path_patterns) + length(var.host_headers) + length(var.http_request_methods) + length(var.source_ips) + length(var.http_headers) + length(var.query_strings) > 0
    error_message = "A listener rule needs at least one condition. AWS rejects a rule with none, and a rule matching everything is what the listener's own default action already does."
  }
}

variable "host_headers" {
  default     = []
  description = "Host headers this rule matches (e.g. ['api.example.com', '*.example.com']). Matched case-insensitively against the Host header, not against the certificate."
}

variable "http_request_methods" {
  default     = []
  description = "HTTP methods this rule matches (e.g. ['GET', 'HEAD']). Matched case-sensitively, and AWS expects them uppercase."
}

variable "source_ips" {
  default     = []
  description = "Client CIDR blocks this rule matches (e.g. ['203.0.113.0/24']). Matched against the address the load balancer sees, which behind a proxy or CloudFront is the proxy's address rather than the end client's — use an http_headers condition on X-Forwarded-For in that case."
}

variable "http_headers" {
  default     = []
  description = "Arbitrary request headers this rule matches, each a header name and the values to match. Values are matched case-insensitively and support the '*' and '?' wildcards."
  type = list(object({
    name   = string
    values = list(string)
  }))
}

variable "query_strings" {
  default     = []
  description = "Query string key/value pairs this rule matches. A key of null matches the value anywhere in the query string regardless of its key."
  type = list(object({
    key   = optional(string)
    value = string
  }))
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the rule."
}
