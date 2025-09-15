output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.apdev_cluster.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.apdev_cluster.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.apdev_cluster.name
}