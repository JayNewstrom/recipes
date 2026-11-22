terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile

  default_tags {
    tags = var.aws_tags
  }
}

provider "aws" {
  alias   = "west"
  region  = "us-west-2"
  profile = var.aws_profile

  default_tags {
    tags = var.aws_tags
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "aws_iam_policy_document" "primary_bucket_policy" {
  statement {
    sid = "1"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.domain_name}/*",
    ]

    principals {
      type = "AWS"

      identifiers = [
        aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn,
      ]
    }
  }
}

data "aws_iam_policy_document" "failover_bucket_policy" {
  statement {
    sid = "1"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.domain_name}.failover/*",
    ]

    principals {
      type = "AWS"

      identifiers = [
        aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn,
      ]
    }
  }
}

resource "aws_s3_bucket" "primary_s3_bucket" {
  bucket = var.domain_name
}

resource "aws_s3_bucket_versioning" "primary_s3_bucket_versioning" {
  bucket = aws_s3_bucket.primary_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "primary_bucket_ownership" {
  bucket = aws_s3_bucket.primary_s3_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "primary_bucket_policy" {
  bucket = aws_s3_bucket.primary_s3_bucket.id
  policy = data.aws_iam_policy_document.primary_bucket_policy.json
}

resource "aws_s3_bucket" "failover_s3_bucket" {
  provider = aws.west
  bucket   = "${var.domain_name}.failover"
}

resource "aws_s3_bucket_versioning" "failover_s3_bucket_versioning" {
  provider = aws.west
  bucket   = aws_s3_bucket.failover_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "failover_bucket_ownership" {
  provider = aws.west
  bucket   = aws_s3_bucket.failover_s3_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "failover_bucket_policy" {
  provider = aws.west
  bucket   = aws_s3_bucket.failover_s3_bucket.id
  policy   = data.aws_iam_policy_document.failover_bucket_policy.json
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.primary_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "failover_bucket" {
  provider = aws.west

  bucket = aws_s3_bucket.failover_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin_group {
    origin_id = "s3-cloudfront-group"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "s3-cloudfront"
    }

    member {
      origin_id = "s3-cloudfront-failover"
    }
  }

  origin {
    domain_name = aws_s3_bucket.primary_s3_bucket.bucket_regional_domain_name
    origin_id   = "s3-cloudfront"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = aws_s3_bucket.failover_s3_bucket.bucket_regional_domain_name
    origin_id   = "s3-cloudfront-failover"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD",
    ]

    cached_methods = [
      "GET",
      "HEAD",
    ]

    target_origin_id = "s3-cloudfront-group"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id

    compress = true

    viewer_protocol_policy = "redirect-to-https"

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.redirect.qualified_arn
      include_body = false
    }
  }

  price_class = var.cloudfront_price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.certificate_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2025"
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    error_caching_min_ttl = 0
    response_page_path    = "/"
  }

  http_version = "http2and3"

  wait_for_deployment = false
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${var.domain_name}.s3.amazonaws.com"
}

resource "aws_acm_certificate" "certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_dns_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => {
      name    = trimsuffix(dvo.resource_record_name, ".")
      type    = dvo.resource_record_type
      content = trimsuffix(dvo.resource_record_value, ".")
    }
  }

  zone_id = var.cloudflare_zone
  name    = each.value.name
  type    = each.value.type
  content = each.value.content
  ttl     = var.dns_validation_ttl
  proxied = false
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.validation : record.name]
}

resource "cloudflare_dns_record" "domain_record" {
  zone_id = var.cloudflare_zone
  name    = var.domain_name
  type    = "CNAME"
  content = aws_cloudfront_distribution.s3_distribution.domain_name
  ttl     = var.dns_ttl
  proxied = false
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

resource "aws_iam_role" "github_actions" {
  name = "RecipesGithubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_oidc_repository_slug
          }
        }
      },
    ]
  })
}

resource "aws_iam_policy" "publisher" {
  name = "RecipesPublish"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.primary_s3_bucket.arn,
          format("%s/*", aws_s3_bucket.primary_s3_bucket.arn),
        ]
      },
      {
        Action   = "cloudfront:CreateInvalidation"
        Effect   = "Allow"
        Resource = aws_cloudfront_distribution.s3_distribution.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_publisher" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.publisher.arn
}

resource "aws_iam_role" "lambda_redirect" {
  name = "RecipesLambdaRedirect"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = [
            "edgelambda.amazonaws.com",
            "lambda.amazonaws.com",
          ]
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_redirect_logs" {
  role       = aws_iam_role.lambda_redirect.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "redirect" {
  type        = "zip"
  source_file = "${path.module}/redirect.js"
  output_path = "${path.module}/redirect.zip"
}

resource "aws_lambda_function" "redirect" {
  function_name    = "RecipesRedirectToIndex"
  role             = aws_iam_role.lambda_redirect.arn
  handler          = "redirect.handler"
  runtime          = "nodejs24.x"
  source_code_hash = data.archive_file.redirect.output_base64sha256
  filename         = data.archive_file.redirect.output_path
  publish          = true
}

resource "aws_iam_role" "replication" {
  name = "RecipesS3Replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "replication" {
  name = "RecipesS3Replication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.primary_s3_bucket.arn,
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.primary_s3_bucket.arn}/*",
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.failover_s3_bucket.arn}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [
    aws_s3_bucket_versioning.primary_s3_bucket_versioning,
    aws_s3_bucket_versioning.failover_s3_bucket_versioning,
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary_s3_bucket.id

  rule {
    id       = "RecipeReplication"
    priority = 0
    status   = "Enabled"

    destination {
      bucket = aws_s3_bucket.failover_s3_bucket.arn
    }
  }
}
