variable "domain_name" {
}

variable "cloudflare_zone" {
}

variable "github_oidc_repository_slug" {
}

variable "cloudflare_api_token" {
}

variable "aws_profile" {
  default = ""
}

variable "aws_tags" {
  type        = map(string)
  default     = {}
  description = "tags for all the resources, if any"
}

variable "cloudfront_price_class" {
  default     = "PriceClass_100" // Only US,Canada,Europe
  description = "CloudFront distribution price class"
}

variable "dns_validation_ttl" {
  default = 120
}

variable "dns_ttl" {
  default = 1 // 1 is automatic.
}

variable "dns_validation_allow_overwrite_records" {
  default = true
}

variable "dns_allow_overwrite_records" {
  default = true
}
