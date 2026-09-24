mock_provider "aws" {}

run "invalid_action_type_is_rejected" {
  command = plan

  variables {
    listener_arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    action_type   = "proxy"
    path_patterns = ["/api/*"]
  }

  expect_failures = [var.action_type]
}

run "priority_outside_the_allowed_range_is_rejected" {
  command = plan

  variables {
    listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    priority         = 99999
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
    path_patterns    = ["/api/*"]
  }

  expect_failures = [var.priority]
}

run "forward_rule_needs_a_destination" {
  command = plan

  variables {
    listener_arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    path_patterns = ["/api/*"]
  }

  expect_failures = [var.target_groups]
}

run "single_and_weighted_destinations_are_mutually_exclusive" {
  command = plan

  variables {
    listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
    target_groups = [
      { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/blue/4444", weight = 90 },
    ]
    path_patterns = ["/api/*"]
  }

  expect_failures = [var.target_groups]
}

run "invalid_redirect_status_code_is_rejected" {
  command = plan

  variables {
    listener_arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    action_type   = "redirect"
    redirect      = { status_code = "HTTP_307" }
    path_patterns = ["/old/*"]
  }

  expect_failures = [var.redirect]
}

run "invalid_fixed_response_content_type_is_rejected" {
  command = plan

  variables {
    listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    action_type    = "fixed-response"
    fixed_response = { content_type = "application/xml" }
    path_patterns  = ["/blocked/*"]
  }

  expect_failures = [var.fixed_response]
}

run "a_rule_with_no_conditions_is_rejected" {
  command = plan

  variables {
    listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
  }

  expect_failures = [var.path_patterns]
}

run "forward_to_one_target_group" {
  command = plan

  variables {
    listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    priority         = 100
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
    path_patterns    = ["/api/*"]
  }

  assert {
    condition     = one(aws_lb_listener_rule.resource.action).type == "forward"
    error_message = "The rule should default to forwarding."
  }

  assert {
    condition     = one(aws_lb_listener_rule.resource.action).target_group_arn == "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
    error_message = "A single destination should be set directly rather than wrapped in a forward block."
  }

  assert {
    condition     = length(aws_lb_listener_rule.resource.condition) == 1
    error_message = "One condition type supplied should produce exactly one condition block."
  }
}

run "weighted_target_groups_produce_a_forward_block" {
  command = plan

  variables {
    listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    target_groups = [
      { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/blue/4444", weight = 90 },
      { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/green/5555", weight = 10 },
    ]
    stickiness_duration = 3600
    path_patterns       = ["/*"]
  }

  assert {
    condition     = length(one(one(aws_lb_listener_rule.resource.action).forward).target_group) == 2
    error_message = "Each weighted destination should produce one target_group entry."
  }

  assert {
    condition     = one(one(one(aws_lb_listener_rule.resource.action).forward).stickiness).duration == 3600
    error_message = "A stickiness duration should reach the forward block, so a canary keeps clients on one side."
  }
}

run "redirect_rule_emits_only_a_redirect_block" {
  command = plan

  variables {
    listener_arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    action_type   = "redirect"
    redirect      = { protocol = "HTTPS", port = "443" }
    path_patterns = ["/*"]
  }

  assert {
    condition     = length(one(aws_lb_listener_rule.resource.action).redirect) == 1
    error_message = "A redirect rule should emit exactly one redirect block."
  }

  assert {
    condition     = one(one(aws_lb_listener_rule.resource.action).redirect).status_code == "HTTP_301"
    error_message = "A redirect should default to a permanent 301."
  }

  assert {
    condition     = length(one(aws_lb_listener_rule.resource.action).fixed_response) == 0
    error_message = "A redirect rule should emit no fixed_response block."
  }
}

run "fixed_response_rule_emits_only_a_fixed_response_block" {
  command = plan

  variables {
    listener_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    action_type    = "fixed-response"
    fixed_response = { content_type = "text/html", status_code = "503", message_body = "<h1>Maintenance</h1>" }
    path_patterns  = ["/*"]
  }

  assert {
    condition     = one(one(aws_lb_listener_rule.resource.action).fixed_response).status_code == "503"
    error_message = "The fixed response status code should pass through unchanged."
  }

  assert {
    condition     = length(one(aws_lb_listener_rule.resource.action).redirect) == 0
    error_message = "A fixed-response rule should emit no redirect block."
  }
}

run "every_condition_type_produces_its_own_block" {
  command = plan

  variables {
    listener_arn         = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    target_group_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
    path_patterns        = ["/api/*"]
    host_headers         = ["api.example.com"]
    http_request_methods = ["GET", "HEAD"]
    source_ips           = ["203.0.113.0/24"]
    http_headers = [
      { name = "X-Tenant", values = ["acme"] },
    ]
    query_strings = [
      { key = "version", value = "2" },
    ]
  }

  assert {
    condition     = length(aws_lb_listener_rule.resource.condition) == 6
    error_message = "Each supplied condition type should produce its own condition block."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    priority         = 100
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/3333"
    path_patterns    = ["/api/*"]
  }
}

run "readme_canary_example" {
  command = plan

  variables {
    listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/web/1111/2222"
    priority     = 200

    target_groups = [
      { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/blue/4444", weight = 90 },
      { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/green/5555", weight = 10 },
    ]

    stickiness_duration = 3600
    host_headers        = ["app.example.com"]
  }
}
