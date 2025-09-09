# App Bucket
resource "aws_s3_bucket" "app" {
  bucket = "${var.bucket_name}-${var.environment}-devops-app"
}

resource "aws_s3_public_access_block" "app_block_public_access" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logs Bucket
resource "aws_s3_bucket" "logs" {
  bucket = "${var.bucket_name}-${var.environment}-devops-logs"
}

resource "aws_s3_bucket_ownership_controls" "logs_ownership" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"

  depends_on = [aws_s3_bucket_ownership_controls.logs_ownership]
}

# Cloudfront
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-s3-nodejs-app-${var.environment}"
  description                       = "OAC for private S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.app.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "s3-origin-${var.environment}"
  }

  enabled             = true
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-origin-${var.environment}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# App Bucket Policy
data "aws_iam_policy_document" "allow_access_from_cdn" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadOnly"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.app.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["${aws_cloudfront_distribution.s3_distribution.arn}"]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cdn" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.allow_access_from_cdn.json
}

resource "null_resource" "upload_build_to_s3" {
  provisioner "local-exec" {
    command = "aws s3 sync ../build s3://${aws_s3_bucket.app.bucket}"
  }

  depends_on = [aws_s3_bucket.app]
}
