# data "aws_route53_zone" "this" {
#   name         = var.zone_name
#   private_zone = false
# }

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "2.10.2"

  # zone_id = data.aws_route53_zone.this.zone_id
  zone_name    = var.zone_name
  private_zone = false

  # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/ResourceRecordTypes.html
  records = [
    for extension in setunion(compact(var.record.extensions), [""]) :
    {
      name           = trimprefix("${extension}.${var.record.subdomain_name}", ".")
      type           = var.record.type
      alias          = var.record.alias
      ttl            = var.record.ttl
      records        = var.record.records
      set_identifier = var.record.set_identifier
    }
  ]
}
