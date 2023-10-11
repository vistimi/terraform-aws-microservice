# https://registry.terraform.io/module/terraform-aws-modules/elb/aws/8.6.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "http" {
  value = {
    tcp_listener_arns = module.elb.http_tcp_listener_arns
    tcp_listener_ids  = module.elb.http_tcp_listener_ids
  }
}

output "https" {
  value = {
    listener_arns = module.elb.https_listener_arns
    listener_ids  = module.elb.https_listener_ids
  }
}

output "lb" {
  value = {
    arn        = module.elb.lb_arn
    arn_suffix = module.elb.lb_arn_suffix
    dns_name   = module.elb.lb_dns_name
    id         = module.elb.lb_id
    zone_id    = module.elb.lb_zone_id
  }
}

output "security_group" {
  value = {
    arn = module.elb.security_group_arn
    id  = module.elb.security_group_id
  }
}

output "target_group" {
  value = {
    arn_suffixes = module.elb.target_group_arn_suffixes
    arns         = module.elb.target_group_arns
    attachments  = module.elb.target_group_attachments
    names        = module.elb.target_group_names
  }
}

# output "security_group" {
#   value = {
#     id = module.elb_sg.security_group_id
#   }
# }
