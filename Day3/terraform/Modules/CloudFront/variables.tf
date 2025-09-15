variable "alb_domain_name" {
  description = "ALB domain name for CloudFront origin"
  type        = string
}

variable "cloudfront_function_arn" {
  description = "CloudFront function ARN for viewer request"
  type        = string
  default     = null
}