variable "domain_name" {
  type        = string
  description = "Domain name for the recipes site and primary S3 bucket"
}

variable "cloudflare_zone" {
  type        = string
  description = "Cloudflare Zone ID for DNS records"
}

variable "github_oidc_repository_slug" {
  type        = string
  description = "GitHub OIDC subject claim pattern allowed to assume the deploy role"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with DNS edit permissions"
}

variable "aws_profile" {
  type        = string
  default     = ""
  description = "AWS CLI profile name (optional)"
}

variable "aws_tags" {
  type        = map(string)
  default     = {}
  description = "tags for all the resources, if any"
}

variable "cloudfront_price_class" {
  type        = string
  default     = "PriceClass_100" // Only US,Canada,Europe
  description = "CloudFront distribution price class"
}

variable "dns_validation_ttl" {
  type        = number
  default     = 120
  description = "TTL in seconds for ACM DNS validation records"
}

variable "dns_ttl" {
  type        = number
  default     = 1 // 1 is automatic.
  description = "TTL in seconds for the site CNAME record (1 for automatic)"
}
