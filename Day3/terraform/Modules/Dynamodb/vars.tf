variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "product"
}

variable "read_capacity" {
  description = "Read capacity for the table"
  type        = number
  default     = 500
}

variable "write_capacity" {
  description = "Write capacity for the table"
  type        = number
  default     = 1000
}