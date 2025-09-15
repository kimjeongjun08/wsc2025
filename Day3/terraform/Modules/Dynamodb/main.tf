# resource "aws_dynamodb_table" "product" {
#   name           = "product"
#   billing_mode   = "PROVISIONED"
#   read_capacity  = 500
#   write_capacity = 1000
#   hash_key       = "id"

#   lifecycle {
#     ignore_changes = [read_capacity, write_capacity]
#   }

#   attribute {
#     name = "id"
#     type = "S"
#   }

#   global_secondary_index {
#     name            = "id-index"
#     hash_key        = "id"
#     read_capacity   = 500
#     write_capacity  = 1000
#     projection_type = "ALL"
#   }

#   tags = {
#     Name = "product"
#   }
# }

# # Auto Scaling for Table Read Capacity
# resource "aws_appautoscaling_target" "product_read_target" {
#   max_capacity       = 4000
#   min_capacity       = 5
#   resource_id        = "table/product"
#   scalable_dimension = "dynamodb:table:ReadCapacityUnits"
#   service_namespace  = "dynamodb"
# }

# resource "aws_appautoscaling_policy" "product_read_policy" {
#   name               = "DynamoDBReadCapacityUtilization:table/product"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.product_read_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.product_read_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.product_read_target.service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "DynamoDBReadCapacityUtilization"
#     }
#     target_value = 70.0
#   }
# }

# # Auto Scaling for Table Write Capacity
# resource "aws_appautoscaling_target" "product_write_target" {
#   max_capacity       = 4000
#   min_capacity       = 5
#   resource_id        = "table/product"
#   scalable_dimension = "dynamodb:table:WriteCapacityUnits"
#   service_namespace  = "dynamodb"
# }

# resource "aws_appautoscaling_policy" "product_write_policy" {
#   name               = "DynamoDBWriteCapacityUtilization:table/product"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.product_write_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.product_write_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.product_write_target.service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "DynamoDBWriteCapacityUtilization"
#     }
#     target_value = 70.0
#   }
# }

# # Auto Scaling for GSI Read Capacity
# resource "aws_appautoscaling_target" "product_gsi_read_target" {
#   max_capacity       = 4000
#   min_capacity       = 5
#   resource_id        = "table/product/index/id-index"
#   scalable_dimension = "dynamodb:index:ReadCapacityUnits"
#   service_namespace  = "dynamodb"
# }

# resource "aws_appautoscaling_policy" "product_gsi_read_policy" {
#   name               = "DynamoDBReadCapacityUtilization:table/product/index/id-index"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.product_gsi_read_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.product_gsi_read_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.product_gsi_read_target.service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "DynamoDBReadCapacityUtilization"
#     }
#     target_value = 70.0
#   }
# }

# # Auto Scaling for GSI Write Capacity
# resource "aws_appautoscaling_target" "product_gsi_write_target" {
#   max_capacity       = 4000
#   min_capacity       = 5
#   resource_id        = "table/product/index/id-index"
#   scalable_dimension = "dynamodb:index:WriteCapacityUnits"
#   service_namespace  = "dynamodb"
# }

# resource "aws_appautoscaling_policy" "product_gsi_write_policy" {
#   name               = "DynamoDBWriteCapacityUtilization:table/product/index/id-index"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.product_gsi_write_target.resource_id
#   scalable_dimension = aws_appautoscaling_target.product_gsi_write_target.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.product_gsi_write_target.service_namespace

#   target_tracking_scaling_policy_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "DynamoDBWriteCapacityUtilization"
#     }
#     target_value = 70.0
#   }
# }