resource "aws_lb_listener_rule" "resource" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type             = var.action_type
    target_group_arn = var.action_type == "forward" && length(var.target_groups) == 0 ? var.target_group_arn : null

    dynamic "forward" {
      for_each = var.action_type == "forward" && length(var.target_groups) > 0 ? [1] : []

      content {
        dynamic "target_group" {
          for_each = var.target_groups

          content {
            arn    = target_group.value.arn
            weight = target_group.value.weight
          }
        }

        dynamic "stickiness" {
          for_each = var.stickiness_duration[*]

          content {
            enabled  = true
            duration = stickiness.value
          }
        }
      }
    }

    dynamic "redirect" {
      for_each = var.action_type == "redirect" ? var.redirect[*] : []

      content {
        status_code = redirect.value.status_code
        protocol    = redirect.value.protocol
        port        = redirect.value.port
        host        = redirect.value.host
        path        = redirect.value.path
        query       = redirect.value.query
      }
    }

    dynamic "fixed_response" {
      for_each = var.action_type == "fixed-response" ? var.fixed_response[*] : []

      content {
        content_type = fixed_response.value.content_type
        status_code  = fixed_response.value.status_code
        message_body = fixed_response.value.message_body
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.path_patterns) > 0 ? [1] : []

    content {
      path_pattern {
        values = var.path_patterns
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.host_headers) > 0 ? [1] : []

    content {
      host_header {
        values = var.host_headers
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.http_request_methods) > 0 ? [1] : []

    content {
      http_request_method {
        values = var.http_request_methods
      }
    }
  }

  dynamic "condition" {
    for_each = length(var.source_ips) > 0 ? [1] : []

    content {
      source_ip {
        values = var.source_ips
      }
    }
  }

  dynamic "condition" {
    for_each = var.http_headers

    content {
      http_header {
        http_header_name = condition.value.name
        values           = condition.value.values
      }
    }
  }

  dynamic "condition" {
    for_each = var.query_strings

    content {
      query_string {
        key   = condition.value.key
        value = condition.value.value
      }
    }
  }

  tags = var.tags
}

output "id" {
  description = "The ID of the rule."
  value       = aws_lb_listener_rule.resource.id
}

output "arn" {
  description = "The ARN of the rule."
  value       = aws_lb_listener_rule.resource.arn
}

output "priority" {
  description = "The rule's evaluation priority, including one AWS assigned when priority was left null."
  value       = aws_lb_listener_rule.resource.priority
}
