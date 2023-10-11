# -----------------
#     ACM
# -----------------
data "aws_route53_zone" "current" {
  for_each = {
    for name in flatten([
      for traffic in local.traffics : [
        for zone in try(var.route53.zones, []) : zone.name
      ] if traffic.listener.protocol == "https"
    ]) : name => {}
  }

  name         = each.key
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "4.3.2"

  for_each = {
    for name in flatten([
      for traffic in local.traffics : [
        for zone in try(var.route53.zones, []) : zone.name
      ] if traffic.listener.protocol == "https"
    ]) : name => {}
  }

  create_certificate     = true
  create_route53_records = true

  key_algorithm     = "RSA_2048"
  validation_method = "DNS"

  domain_name = "${var.route53.record.subdomain_name}.${each.key}"
  zone_id     = data.aws_route53_zone.current[each.key].zone_id

  subject_alternative_names = [for prefix in distinct(compact(var.route53.record.prefixes)) : "${prefix}.${var.route53.record.subdomain_name}.${each.key}"]

  wait_for_validation = true
  validation_timeout  = "15m"

  tags = var.tags
}

# -----------------
#     Route53
# -----------------
// ecs service discovery is alternative to route53
module "route53_records" {
  source = "../record"

  for_each = { for zone in coalesce(try(var.route53.zones, []), []) : zone.name => {} }

  zone_name = each.key
  record = {
    subdomain_name = var.route53.record.subdomain_name
    prefixes       = var.route53.record.prefixes
    type           = "A"
    alias = {
      name    = "dualstack.${module.elb.lb.dns_name}"
      zone_id = module.elb.lb.zone_id
    }
  }
}

module "elb" {
  source = "../elb"

  name                     = var.name
  vpc                      = var.vpc
  layer7_to_layer4_mapping = local.layer7_to_layer4_mapping
  traffics                 = local.traffics
  deployment_type          = var.ecs.service.ec2 != null ? "ec2" : "fargate"
  certificate_arn          = try(one(values(module.acm)).acm_certificate_arn, null)

  tags = var.tags
}
