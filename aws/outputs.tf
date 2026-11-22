output "aws_bucket_name" {
  description = "Primary S3 bucket name for GitHub Actions AWS_BUCKET_NAME secret"
  value       = aws_s3_bucket.primary_s3_bucket.bucket
}

output "aws_cloudfront_distribution_id" {
  description = "CloudFront distribution ID for GitHub Actions AWS_CLOUDFRONT_DISTRIBUTION secret"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "aws_cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "aws_github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions AWS_ROLE secret"
  value       = aws_iam_role.github_actions.arn
}
