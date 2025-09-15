resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "bucket" {
  bucket = "apdev-deploy-file-s3-bucket-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_object" "static" {
  for_each = fileset("${path.module}/static", "*")
  
  bucket = aws_s3_bucket.bucket.id
  key    = "${each.value}"
  source = "${path.module}/static/${each.value}"
  etag   = filemd5("${path.module}/static/${each.value}")
}