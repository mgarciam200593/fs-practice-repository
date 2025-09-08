resource "aws_s3_bucket" "app" {
  bucket = "${var.bucket_name}-${terraform.workspace}-mgarcia-app"
}

resource "aws_s3_bucket_public_access_block" "app_block_public_access" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.app]
}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.bucket_name}-${terraform.workspace}-mgarcia-logs"
}

resource "aws_s3_bucket_ownership_controls" "logs_ownership" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }

  depends_on = [aws_s3_bucket.logs]
}

resource "aws_s3_bucket_public_access_block" "logs_block" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = false
  block_public_policy     = true
  ignore_public_acls      = false
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "logs_acl" {
  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"

  depends_on = [
    aws_s3_bucket_ownership_controls.logs_ownership,
    aws_s3_bucket_public_access_block.logs_block
  ]
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "node-app-oac"
  description                       = "OAC for private S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.app.bucket_regional_domain_name
    origin_id   = "s3-node-app-origin"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-node-app-origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront-logs/"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_s3_bucket_policy" "app_policy" {
  bucket = aws_s3_bucket.app.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "AllowCloudFrontServicePrincipalReadOnly",
        Effect : "Allow",
        Principal : {
          Service : "cloudfront.amazonaws.com"
        },
        Action : "s3:GetObject",
        Resource : "${aws_s3_bucket.app.arn}/*",
        Condition : {
          StringEquals : {
            "AWS:SourceArn" : "${aws_cloudfront_distribution.cdn.arn}"
          }
        }
      }
    ]
  })
}

resource "null_resource" "upload_build_to_s3" {
  provisioner "local-exec" {
    command = "aws s3 sync ../build s3://${aws_s3_bucket.app.bucket}"
  }

  depends_on = [aws_s3_bucket.app]
}
