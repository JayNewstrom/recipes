This website is deployed to AWS.

Using a few AWS tools:
- S3
- CloudFront
- Lambda@Edge
- Iam
- Certificate Manager

This directory includes a Terraform script that creates all the infrastructure needed to run the site, as well as do automatic deployments when changes are pushed.

## Terraform
This assumes you are already authenticated with an AWS administrator role setup on the command line.

First run - `terraform init`

Run with - `terraform apply -var-file recipes.tfvars`


Example `recipes.tfvars`:
```
domain_name = "recipes.newstrom.life"

# Go to dash.cloudflare.com, click on the domain you want to use, scroll down, you'll see Zone ID on the right side. 
cloudflare_zone = "a000a000a000a000aaa00aaa0"
cloudflare_api_token = "aaa0aaa0"

# Can also be used with wildcards like "repo:JayNewstrom/recipes:*". 
github_oidc_repository_slug = "repo:JayNewstrom/recipes:ref:refs/heads/master"
```

## GitHub Actions Secrets
Deploys happen automatically when pushed to `master`.

Run `terraform output` to retrieve the values for the GitHub Actions secrets, then add them in the repository settings (e.g., https://github.com/JayNewstrom/recipes/settings/secrets/actions):
- `AWS_BUCKET_NAME`: value of `aws_bucket_name`
- `AWS_CLOUDFRONT_DISTRIBUTION`: value of `aws_cloudfront_distribution_id`
- `AWS_ROLE`: value of `aws_github_actions_role_arn`
