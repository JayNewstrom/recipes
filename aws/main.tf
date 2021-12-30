terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
}

provider "aws" {
  alias   = "west"
  region  = "us-west-2"
  profile = var.aws_profile
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  validation_domains = distinct(
  [
  for k, v in aws_acm_certificate.certificate[0].domain_validation_options : merge(
  tomap(v), { domain_name = replace(v.domain_name, "*.", "") }
  )
  ]
  )
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
  acl    = "private"
  policy = data.aws_iam_policy_document.primary_bucket_policy.json
  tags   = var.aws_tags

  versioning {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      replication_configuration
    ]
  }
}

resource "aws_s3_bucket" "failover_s3_bucket" {
  provider = aws.west
  bucket   = "${var.domain_name}.failover"
  acl      = "private"
  policy   = data.aws_iam_policy_document.failover_bucket_policy.json
  tags     = var.aws_tags

  versioning {
    enabled = true
  }
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

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [
    aws_s3_bucket.primary_s3_bucket,
    aws_s3_bucket.failover_s3_bucket
  ]

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
    domain_name = "${var.domain_name}.s3.amazonaws.com"
    origin_id   = "s3-cloudfront"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = "${var.domain_name}.failover.s3.amazonaws.com"
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

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    compress = true

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000

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
    acm_certificate_arn = aws_acm_certificate_validation.certificate_validation.certificate_arn
    ssl_support_method  = "sni-only"
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    error_caching_min_ttl = 0
    response_page_path    = "/"
  }

  wait_for_deployment = false
  tags                = var.aws_tags
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "access-identity-${var.domain_name}.s3.amazonaws.com"
}

resource "aws_acm_certificate" "certificate" {
  count             = 1
  domain_name       = var.domain_name
  validation_method = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  tags = var.aws_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "validation" {
  count = 1

  zone_id = var.cloudflare_zone
  name    = element(local.validation_domains, count.index)["resource_record_name"]
  type    = element(local.validation_domains, count.index)["resource_record_type"]
  value   = replace(element(local.validation_domains, count.index)["resource_record_value"], "/.$/", "")
  ttl     = var.dns_validation_ttl
  proxied = false

  allow_overwrite = var.dns_validation_allow_overwrite_records

  depends_on = [aws_acm_certificate.certificate]
}

resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn = aws_acm_certificate.certificate[0].arn

  validation_record_fqdns = cloudflare_record.validation.*.hostname
}

resource "cloudflare_record" "domain_record" {
  zone_id = var.cloudflare_zone
  name    = var.domain_name
  type    = "CNAME"
  value   = aws_cloudfront_distribution.s3_distribution.domain_name
  ttl     = var.dns_ttl
  proxied = false

  allow_overwrite = var.dns_allow_overwrite_records
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = ["a031c46782e6e6c662c2c87c76da9aa62ccabd8e"]

  tags = var.aws_tags
}

resource "aws_iam_role" "github_actions" {
  name = "RecipesGithubActionsRole"

  assume_role_policy  = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRoleWithWebIdentity"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.github_oidc_repository_slug
          }
        }
      },
    ]
  })
  managed_policy_arns = [aws_iam_policy.publisher.arn]

  tags = var.aws_tags
}

resource "aws_iam_policy" "publisher" {
  name = "RecipesPublish"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
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

resource "aws_iam_role" "lambda_redirect" {
  name = "RecipesLambdaRedirect"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = [
            "edgelambda.amazonaws.com",
            "lambda.amazonaws.com",
          ]
        }
      },
    ]
  })

  tags = var.aws_tags
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
  runtime          = "nodejs14.x"
  source_code_hash = data.archive_file.redirect.output_base64sha256
  filename         = data.archive_file.redirect.output_path
  publish          = true
}

resource "aws_iam_role" "replication" {
  name = "RecipesS3Replication"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication" {
  name = "RecipesS3Replication"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.primary_s3_bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
         "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.primary_s3_bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.failover_s3_bucket.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket_replication_configuration" "replication" {
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
