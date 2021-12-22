This website is deployed to AWS.

Using a few tools:
- S3
- CloudFront
- Lambda@Edge
- Iam
- Certificate Manager

This directory includes a terraform script that creates all the infrastructure needed to run the site, as well as do automatic deployments when changes are pushed.

Run with - `terraform apply -var-file recipes2.tfvars -auto-approve`
