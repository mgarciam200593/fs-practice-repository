output "public_url" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "Domain Name of CloudFront Distribution to make requests to app"
}