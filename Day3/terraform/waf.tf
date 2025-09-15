resource "aws_wafv2_web_acl" "apdev_waf" {
  name  = "apdev-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "user-pody-email"
    priority = 0

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          not_statement {
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
    name     = "apdev-uri-body-rule"
    priority = 1

    action {
      block {}
    }

    statement {
      or_statement {
        statement {
          and_statement {
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
            statement {
              not_statement {
                statement {
                  regex_match_statement {
                    regex_string = "^\\s*\\{\\s*(\"(requestid|uuid|username|email|status_message)\"\\s*:\\s*[^,}]+\\s*,?\\s*){5}\\}\\s*$"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "COMPRESS_WHITE_SPACE"
                    }
                  }
                }
              }
            }
          }
        }
        statement {
          and_statement {
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
              not_statement {
                statement {
                  regex_match_statement {
                    regex_string = "^\\s*\\{\\s*(\"(requestid|uuid|id|name|price)\"\\s*:\\s*[^,}]+\\s*,?\\s*){5}\\}\\s*$"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "COMPRESS_WHITE_SPACE"
                    }
                  }
                }
              }
            }
          }
        }
        statement {
          and_statement {
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
              not_statement {
                statement {
                  regex_match_statement {
                    regex_string = "^\\s*\\{\\s*(\"(requestid|uuid|length)\"\\s*:\\s*[^,}]+\\s*,?\\s*){3}\\}\\s*$"
                    field_to_match {
                      body {
                        oversize_handling = "CONTINUE"
                      }
                    }
                    text_transformation {
                      priority = 0
                      type     = "COMPRESS_WHITE_SPACE"
                    }
                  }
                }
              }
            }
          }
        }
        statement {
          and_statement {
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
              not_statement {
                statement {
                  regex_match_statement {
                    regex_string = "^((email|requestid|uuid)=[^&]+(&(email|requestid|uuid)=[^&]+)*)?$"
                    field_to_match {
                      query_string {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "URL_DECODE"
                    }
                  }
                }
              }
            }
          }
        }
        statement {
          and_statement {
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
              not_statement {
                statement {
                  regex_match_statement {
                    regex_string = "^((id|requestid|uuid)=[^&]+(&(id|requestid|uuid)=[^&]+)*)?$"
                    field_to_match {
                      query_string {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "URL_DECODE"
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
      metric_name                = "apdev-uri-body-rule"
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
  name              = "aws-waf-logs-cloudwatch"
  retention_in_days = 7

  tags = {
    Name = "aws-waf-logs-cloudwatch"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  resource_arn            = aws_wafv2_web_acl.apdev_waf.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_log_group.arn]
}