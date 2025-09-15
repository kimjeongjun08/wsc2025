# Cache Policy
resource "aws_cloudfront_cache_policy" "apdev_cdn_cache" {
  name        = "apdev-cdn-cache"
  comment     = "Cache policy for apdev CDN"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false

    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings {
        items = ["id"]
      }
    }

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

# Origin Request Policy (All Viewer)
resource "aws_cloudfront_origin_request_policy" "all_viewer" {
  name    = "apdev-all-viewer-policy"
  comment = "All viewer headers, cookies, and query strings"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewer"
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "apdev_cdn" {
  origin {
    domain_name = var.alb_domain_name
    origin_id   = "apdev-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = false
  comment         = "apdev CDN distribution"

  # Default behavior
  default_cache_behavior {
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "apdev-alb"
    compress                   = true
    viewer_protocol_policy     = "allow-all"
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"  # CachingDisabled
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.all_viewer.id

    dynamic "function_association" {
      for_each = var.cloudfront_function_arn != null ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = var.cloudfront_function_arn
      }
    }
  }

  # /v1/product behavior
  ordered_cache_behavior {
    path_pattern               = "/v1/product*"
    allowed_methods            = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "apdev-alb"
    compress                   = true
    viewer_protocol_policy     = "allow-all"
    cache_policy_id            = aws_cloudfront_cache_policy.apdev_cdn_cache.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.all_viewer.id

    dynamic "function_association" {
      for_each = var.cloudfront_function_arn != null ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = var.cloudfront_function_arn
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "apdev-cdn"
  }
}