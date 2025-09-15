variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "apdev-ecs-cluster"
}

variable "vpc_id" {
  description = "VPC ID for ECS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS instances"
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group ID for ECS instances"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile for ECS instances"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "product_tg_arn" {
  description = "ARN of product target group"
  type        = string
}

variable "user_tg_arn" {
  description = "ARN of user target group"
  type        = string
}

variable "stress_tg_arn" {
  description = "ARN of stress target group"
  type        = string
}

variable "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint for database connection"
  type        = string
}