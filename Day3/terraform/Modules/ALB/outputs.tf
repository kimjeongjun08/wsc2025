output "alb_arn" {
  description = "ARN of the ALB"
  value       = aws_lb.apdev_alb.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.apdev_alb.dns_name
}

output "product_tg_arn" {
  description = "ARN of product target group"
  value       = aws_lb_target_group.apdev_product_tg.arn
}

output "user_tg_arn" {
  description = "ARN of user target group"
  value       = aws_lb_target_group.apdev_user_tg.arn
}

output "stress_tg_arn" {
  description = "ARN of stress target group"
  value       = aws_lb_target_group.apdev_stress_tg.arn
}