output "bucket" {
  value = {
    arn                           = module.s3_bucket.s3_bucket_arn
    bucket_domain_name            = module.s3_bucket.s3_bucket_bucket_domain_name
    bucket_regional_domain_name   = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    hosted_zone_id                = module.s3_bucket.s3_bucket_hosted_zone_id
    name                          = module.s3_bucket.s3_bucket_id
    lifecycle_configuration_rules = module.s3_bucket.s3_bucket_lifecycle_configuration_rules
    policy                        = module.s3_bucket.s3_bucket_policy
    region                        = module.s3_bucket.s3_bucket_region
    website_domain                = module.s3_bucket.s3_bucket_website_domain
    website_endpoint              = module.s3_bucket.s3_bucket_website_endpoint
  }
}
