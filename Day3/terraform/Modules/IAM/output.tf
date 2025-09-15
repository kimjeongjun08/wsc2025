output "apdev_admin_instance_profile" {
  value = aws_iam_instance_profile.apdev_admin.name
}

output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}
