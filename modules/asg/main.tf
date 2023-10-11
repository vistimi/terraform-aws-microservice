# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/blob/master/examples/complete/main.tf
module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"

  name            = var.name
  use_name_prefix = false
  key_name        = var.key_name # to SSH into instance

  # iam configuration
  create_iam_instance_profile = true
  iam_role_name               = var.name
  iam_role_use_name_prefix    = false
  iam_role_path               = "/ec2/"
  iam_role_description        = "ASG role for ${var.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:${local.partition}:iam::${local.partition}:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    AmazonSSMManagedInstanceCore        = "arn:${local.partition}:iam::${local.partition}:policy/AmazonSSMManagedInstanceCore"
  }
  iam_role_tags = var.tags


  # launch template configuration
  create_launch_template          = true
  launch_template_use_name_prefix = false
  tag_specifications = concat(
    var.use_spot ? [{
      resource_type = "spot-instances-request"
      tags          = merge(var.tags, { Name = "${var.name}-spot-instance-request" })
    }] : []
    , [{
      resource_type = "instance"
      tags          = merge(var.tags, { Name = "${var.name}-instance" })
  }])
  instance_market_options = var.use_spot ? {
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#market-options
    market_type = "spot"
    # spot_options = {
    #   block_duration_minutes = 60
    # }
  } : {}
  instance_type               = var.instance_type
  image_id                    = var.image_id
  user_data                   = var.user_data_base64
  launch_template_name        = var.name
  launch_template_description = "${var.name} asg launch template"
  update_default_version      = true
  ebs_optimized               = false # optimized ami does not support ebs_optimized
  # metadata_options = {
  # # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#metadata-options
  #   http_endpoint               = "enabled"
  #   http_tokens                 = "required"
  #   http_put_response_hop_limit = 32
  # }

  # wait_for_capacity_timeout = 0
  enable_monitoring = true
  enabled_metrics = [
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTotalInstances"
  ]
  # maintenance_options = { // new
  # auto_recovery = "default"
  # }

  // for public subnets
  // https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-interfaces
  network_interfaces = [
    {
      associate_public_ip_address = true
      delete_on_termination       = true
      description                 = "eth0"
      device_index                = 0
      security_groups             = [module.autoscaling_sg.security_group_id]
    }
  ]
  # cpu_options = {
  #   core_count       = 1
  #   threads_per_core = 1
  # }
  # capacity_reservation_specification = {
  #   capacity_reservation_preference = "open"
  # }
  # credit_specification = {
  #   cpu_credits = "standard"
  # }
  # block_device_mappings = [
  #   {
  #     # Root volume
  #     device_name = "/dev/xvda"
  #     no_device   = 0
  #     ebs = {
  #       delete_on_termination = true
  #       encrypted             = false
  #       volume_size           = 30
  #       volume_type           = "gp3"
  #     }
  #   }
  # ]

  # asg configuration
  ignore_desired_capacity_changes = false
  min_size                        = floor(var.min_count * var.capacity_provider.weight / var.capacity_weight_total)
  max_size                        = ceil(var.max_count * var.capacity_provider.weight / var.capacity_weight_total)
  desired_capacity                = ceil(var.desired_count * var.capacity_provider.weight / var.capacity_weight_total)
  vpc_zone_identifier             = local.subnets
  health_check_type               = "EC2"
  target_group_arns               = var.target_group_arns
  security_groups                 = [module.autoscaling_sg.security_group_id]
  service_linked_role_arn         = aws_iam_service_linked_role.autoscaling.arn
  instance_refresh                = var.instance_refresh

  # initial_lifecycle_hooks = [
  #   {
  #     name                 = "StartupLifeCycleHook"
  #     default_result       = "CONTINUE"
  #     heartbeat_timeout    = 60
  #     lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  #     notification_metadata = jsonencode({
  #       "event"         = "launch",
  #       "timestamp"     = timestamp(),
  #       "auto_scaling"  = var.name,
  #       "group"         = each.key,
  #       "instance_type" = var.instance.ec2.instance_type
  #     })
  #     notification_target_arn = null
  #     role_arn                = aws_iam_policy.ecs_task_logs.arn
  #   },
  #   {
  #     name                 = "TerminationLifeCycleHook"
  #     default_result       = "CONTINUE"
  #     heartbeat_timeout    = 180
  #     lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  #     notification_metadata = jsonencode({
  #       "event"         = "termination",
  #       "timestamp"     = timestamp(),
  #       "auto_scaling"  = var.name,
  #       "group"         = each.key,
  #       "instance_type" = var.instance.ec2.instance_type
  #     })
  #     notification_target_arn = null
  #     role_arn                = aws_iam_policy.ecs_task_logs.arn
  #   }
  # ]

  # schedule configuration
  create_schedule = false
  schedules       = {}

  # scaling configuration
  scaling_policies = {
    # # scale based CPU usage
    avg-cpu-policy-greater-than-target = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
          # resource_label         = "MyLabel"  # should not be precised with ASGAverageCPUUtilization
        }
        target_value = 70 // TODO: var.target_capacity_cpu
      }
    },
    # # scale based on previous traffic
    # predictive-scaling = {
    #   policy_type = "PredictiveScaling"
    #   predictive_scaling_configuration = {
    #     mode                         = "ForecastAndScale"
    #     scheduling_buffer_time       = 10
    #     max_capacity_breach_behavior = "IncreaseMaxCapacity"
    #     max_capacity_buffer          = 10
    #     metric_specification = {
    #       target_value = 32
    #       predefined_scaling_metric_specification = {
    #         predefined_metric_type = "ASGAverageCPUUtilization"
    #         resource_label         = "testLabel"
    #       }
    #       predefined_load_metric_specification = {
    #         predefined_metric_type = "ASGTotalCPUUtilization"
    #         resource_label         = "testLabel"
    #       }
    #     }
    #   }
    # },
    # # scale based on ALB requests
    # request-count-per-target = {
    #   policy_type               = "TargetTrackingScaling"
    #   estimated_instance_warmup = 120
    #   target_tracking_configuration = {
    #     predefined_metric_specification = {
    #       predefined_metric_type = "ALBRequestCountPerTarget"
    #       resource_label         = "${module.elb.lb_arn_suffix}/${module.elb.target_group_arn_suffixes[0]}"
    #     }
    #     target_value = 800
    #   }
    # },
  }

  autoscaling_group_tags = {}
  tags                   = var.tags

  depends_on = [aws_iam_service_linked_role.autoscaling]
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.${local.dns_suffix}"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.name

  # Sometimes good sleep is required to have some IAM resources created before they can be used
  provisioner "local-exec" {
    command = "sleep 10"
  }

  tags = var.tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  description = "Autoscaling group security group" # "Security group with HTTP port open for everyone, and HTTPS open just for the default security group"
  vpc_id      = var.vpc.id
  name        = var.name


  // only accept incoming traffic from load balancer
  computed_ingress_with_source_security_group_id = [for target in distinct([for traffic in var.traffics : {
    port     = traffic.target.port
    protocol = traffic.target.protocol
    }]) : {
    // dynamic port mapping requires all the ports open
    from_port                = var.port_mapping == "dynamic" ? 32768 : target.port
    to_port                  = var.port_mapping == "dynamic" ? 65535 : target.port
    protocol                 = var.layer7_to_layer4_mapping[target.protocol]
    description              = join(" ", ["Load", "Balancer", target.protocol, var.port_mapping == "dynamic" ? 32768 : target.port, "-", var.port_mapping == "dynamic" ? 65535 : target.port])
    source_security_group_id = var.source_security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1

  // accept SSH if key
  ingress_with_cidr_blocks = var.key_name != null ? [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH"
      cidr_blocks = "0.0.0.0/0"
    },
  ] : []
  egress_rules = ["all-all"]

  tags = var.tags
}
