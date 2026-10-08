resource "aws_s3_bucket" "artefakte" {
  bucket = "seclab-artefakte"
}

resource "aws_s3_bucket_public_access_block" "artefakte" {
  bucket                  = aws_s3_bucket.artefakte.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
