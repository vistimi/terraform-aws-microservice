# https://registry.terraform.io/module/terraform-aws-modules/elb/aws/8.6.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "elb" {
  value = module.elb
}

output "acm" {
  value = {
    for key, acm in module.acm : key => {
      acm_certificate_arn                       = acm.acm_certificate_arn
      acm_certificate_domain_validation_options = acm.acm_certificate_domain_validation_options
      acm_certificate_status                    = acm.acm_certificate_status
      acm_certificate_validation_emails         = acm.acm_certificate_validation_emails
      distinct_domain_names                     = acm.distinct_domain_names
      validation_domains                        = acm.validation_domains
      validation_route53_record_fqdns           = acm.validation_route53_record_fqdns
    }
  }
}

output "route53" {
  value = {
    records = {
      for key, record in module.route53_records : key => {
        name = record.name
        fqdn = record.fqdn
      }
    }
  }
}

# https://registry.terraform.io/module/terraform-aws-modules/autoscaling/aws/6.10.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "asg" {
  value = module.asg
}

# https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/outputs.tf
output "cluster" {
  value = {
    arn                            = module.ecs.cluster_arn
    id                             = module.ecs.cluster_id
    name                           = module.ecs.cluster_name
    cloudwatch_log_group_name      = module.ecs.cloudwatch_log_group_name
    cloudwatch_log_group_arn       = module.ecs.cloudwatch_log_group_arn
    cluster_capacity_providers     = module.ecs.cluster_capacity_providers
    autoscaling_capacity_providers = module.ecs.autoscaling_capacity_providers
    task_exec_iam_role_name        = module.ecs.task_exec_iam_role_name
    task_exec_iam_role_arn         = module.ecs.task_exec_iam_role_arn
    task_exec_iam_role_unique_id   = module.ecs.task_exec_iam_role_unique_id
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/module/service/outputs.tf
output "service" {
  value = {
    # service
    id   = one(values(module.ecs.services)).id
    name = one(values(module.ecs.services)).name
    # service iam role
    iam_role_arn       = one(values(module.ecs.services)).iam_role_arn
    iam_role_name      = one(values(module.ecs.services)).iam_role_name
    iam_role_unique_id = one(values(module.ecs.services)).iam_role_unique_id
    # container
    container_definitions = one(values(module.ecs.services)).container_definitions
    # task definition
    task_definition_arn      = one(values(module.ecs.services)).task_definition_arn
    task_definition_revision = one(values(module.ecs.services)).task_definition_revision
    task_definition_family   = one(values(module.ecs.services)).task_definition_family
    # task execution iam role
    task_exec_iam_role_name      = one(values(module.ecs.services)).task_exec_iam_role_name
    task_exec_iam_role_arn       = one(values(module.ecs.services)).task_exec_iam_role_arn
    task_exec_iam_role_unique_id = one(values(module.ecs.services)).task_exec_iam_role_unique_id
    # task iam role
    task_iam_role_arn       = one(values(module.ecs.services)).tasks_iam_role_arn
    task_iam_role_name      = one(values(module.ecs.services)).tasks_iam_role_name
    task_iam_role_unique_id = one(values(module.ecs.services)).tasks_iam_role_unique_id
    # task set
    task_set_id               = one(values(module.ecs.services)).task_set_id
    task_set_arn              = one(values(module.ecs.services)).task_set_arn
    task_set_stability_status = one(values(module.ecs.services)).task_set_stability_status
    task_set_status           = one(values(module.ecs.services)).task_set_status
    # autoscaling
    autoscaling_policies          = one(values(module.ecs.services)).autoscaling_policies
    autoscaling_scheduled_actions = one(values(module.ecs.services)).autoscaling_scheduled_actions
    # security group
    security_group_arn = one(values(module.ecs.services)).security_group_arn
    security_group_id  = one(values(module.ecs.services)).security_group_id
  }
}
