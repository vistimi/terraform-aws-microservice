# https://registry.terraform.io/module/terraform-aws-modules/autoscaling/aws/6.10.0?utm_content=documentLink&utm_medium=Visual+Studio+Code&utm_source=terraform-ls#outputs
output "autoscaling" {
  value = {
    group_arn                       = module.asg.autoscaling_group_arn
    group_availability_zones        = module.asg.autoscaling_group_availability_zones
    group_default_cooldown          = module.asg.autoscaling_group_default_cooldown
    group_desired_capacity          = module.asg.autoscaling_group_desired_capacity
    group_enabled_metrics           = module.asg.autoscaling_group_enabled_metrics
    group_health_check_grace_period = module.asg.autoscaling_group_health_check_grace_period
    group_health_check_type         = module.asg.autoscaling_group_health_check_type
    group_id                        = module.asg.autoscaling_group_id
    group_load_balancers            = module.asg.autoscaling_group_load_balancers
    group_max_size                  = module.asg.autoscaling_group_max_size
    group_min_size                  = module.asg.autoscaling_group_min_size
    group_name                      = module.asg.autoscaling_group_name
    group_target_group_arns         = module.asg.autoscaling_group_target_group_arns
    group_vpc_zone_identifier       = module.asg.autoscaling_group_vpc_zone_identifier
    policy_arns                     = module.asg.autoscaling_policy_arns
    schedule_arns                   = module.asg.autoscaling_schedule_arns
  }
}

output "iam" {
  value = {
    instance_profile_arn    = module.asg.iam_instance_profile_arn
    instance_profile_id     = module.asg.iam_instance_profile_id
    instance_profile_unique = module.asg.iam_instance_profile_unique
    role_arn                = module.asg.iam_role_arn
    role_name               = module.asg.iam_role_name
    role_unique_id          = module.asg.iam_role_unique_id
  }
}

output "launch" {
  value = {
    template_arn             = module.asg.launch_template_arn
    template_default_version = module.asg.launch_template_default_version
    template_id              = module.asg.launch_template_id
    template_latest_version  = module.asg.launch_template_latest_version
    template_name            = module.asg.launch_template_name
  }
}
