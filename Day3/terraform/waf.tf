resource "aws_wafv2_web_acl" "apdev_waf" {
  provider = aws.us_east_1
  name     = "apdev-waf"
  scope    = "CLOUDFRONT"

  default_action {
    block {}
  }

  rule {
    name     = "user-pody-email"
    priority = 0

    action {
      allow {}
    }

    statement {
      and_statement {
        statement {
          regex_match_statement {
            regex_string = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
            field_to_match {
              json_body {
                match_pattern {
                  included_paths = ["/email"]
                }
                match_scope                 = "ALL"
                invalid_fallback_behavior   = "MATCH"
                oversize_handling          = "MATCH"
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "/v1/user"
            positional_constraint = "EXACTLY"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "POST"
            positional_constraint = "EXACTLY"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "post-pody-email"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "apdev-post-rule"
    priority = 1

    action {
      allow {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "curl/8.7.1"
            positional_constraint = "EXACTLY"
            field_to_match {
              single_header {
                name = "user-agent"
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          or_statement {
            statement {
              and_statement {
                statement {
                  byte_match_statement {
                    search_string         = "POST"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "/v1/user"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9]+$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/requestid"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/uuid"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/email"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "username"
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "status_message"
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
            statement {
              and_statement {
                statement {
                  byte_match_statement {
                    search_string         = "POST"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "/v1/product"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9]+$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/requestid"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/uuid"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "id"
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "name"
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "price"
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
            statement {
              and_statement {
                statement {
                  byte_match_statement {
                    search_string         = "POST"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "/v1/stress"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9]+$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/requestid"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
                    field_to_match {
                      json_body {
                        match_pattern {
                          included_paths = ["/uuid"]
                        }
                        match_scope                 = "ALL"
                        invalid_fallback_behavior   = "MATCH"
                        oversize_handling          = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "length"
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "apdev-post-rule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "apdev-get-rule"
    priority = 2

    action {
      allow {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "curl/8.7.1"
            positional_constraint = "EXACTLY"
            field_to_match {
              single_header {
                name = "user-agent"
              }
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          or_statement {
            statement {
              and_statement {
                statement {
                  byte_match_statement {
                    search_string         = "GET"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "/v1/product"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "id="
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      query_string {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9]+$"
                    field_to_match {
                      single_query_argument {
                        name = "requestid"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
                    field_to_match {
                      single_query_argument {
                        name = "uuid"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[^&]*&[^&]*&[^&]*$"
                    field_to_match {
                      query_string {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
            statement {
              and_statement {
                statement {
                  byte_match_statement {
                    search_string         = "GET"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      method {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "/v1/user"
                    positional_constraint = "EXACTLY"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  byte_match_statement {
                    search_string         = "email="
                    positional_constraint = "CONTAINS"
                    field_to_match {
                      query_string {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9]+$"
                    field_to_match {
                      single_query_argument {
                        name = "requestid"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
                    field_to_match {
                      single_query_argument {
                        name = "uuid"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
                statement {
                  regex_match_statement {
                    regex_string = "^[^&]*&[^&]*&[^&]*$"
                    field_to_match {
                      query_string {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "NONE"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "apdev-get-rule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "apdev-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "apdev-waf"
  }
}

resource "aws_cloudwatch_log_group" "waf_log_group" {
  provider          = aws.us_east_1
  name              = "aws-waf-logs-cloudwatch"
  retention_in_days = 7

  tags = {
    Name = "aws-waf-logs-cloudwatch"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  provider                = aws.us_east_1
  resource_arn            = aws_wafv2_web_acl.apdev_waf.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]
}