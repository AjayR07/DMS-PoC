resource "aws_s3_bucket" "dms-target-s3" {
  bucket = "dms-target-s3"
  tags = {
    Name        = "dms-target-s3"
  }
}

resource "aws_s3_bucket_acl" "dms-target-s3-acl" {
  bucket = aws_s3_bucket.dms-target-s3.id
  acl    = "private"
}
