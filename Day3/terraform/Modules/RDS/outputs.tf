output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.apdev_rds_instance.endpoint
}

output "rds_proxy_endpoint" {
  description = "RDS proxy endpoint"
  value       = aws_db_proxy.apdev_rds_proxy.endpoint
}