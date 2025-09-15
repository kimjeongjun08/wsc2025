resource "aws_dynamodb_table" "product" {
  name           = "product"
  billing_mode   = "PAY_PER_REQUEST"

  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  global_secondary_index {
    name               = "id-index"
    hash_key           = "id"
    projection_type    = "ALL"
  }

  tags = {
    Name = "product"
  }
}
