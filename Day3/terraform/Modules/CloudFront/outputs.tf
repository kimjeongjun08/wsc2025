output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.apdev_cdn.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.apdev_cdn.domain_name
}

output "cache_policy_id" {
  description = "Cache policy ID"
  value       = aws_cloudfront_cache_policy.apdev_cdn_cache.id
}