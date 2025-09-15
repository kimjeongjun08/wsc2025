resource "aws_ecr_repository" "product" {
  name                 = "product"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "stress" {
  name                 = "stress"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "user" {
  name                 = "user"
  image_tag_mutability = "MUTABLE"
}