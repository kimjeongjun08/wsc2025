variable "name" {
  description = "Name prefix for resources"
  type        = string
  default = "apdev"
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.medium"
}

variable "bastion_sg" {
  description = "Security group ID for bastion host"
  type        = string
}

variable "puba_subnet_id" {
  description = "Public subnet ID for bastion host"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile for bastion host"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS endpoint for MySQL connection"
  type        = string
  default     = ""
}

variable "s3_bucket_id" {
  description = "S3 bucket ID for file downloads"
  type        = string
}