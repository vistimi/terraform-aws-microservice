locals {
  # https://github.com/aws/amazon-ecs-agent/blob/master/README.md
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-gpu.html
  # <<- is required compared to << because there should be no identation for EOT and EOF to work properly
  # TODO: remove ECS_NVIDIA_RUNTIME
  user_data = {
    for capacity in try(var.ecs.service.ec2.capacities, []) : capacity.type => <<-EOT
        #!/bin/bash
        cat <<'EOF' >> /etc/ecs/ecs.config
        ECS_CLUSTER=${var.name}
        ${capacity.type == "SPOT" ? "ECS_ENABLE_SPOT_INSTANCE_DRAINING=true" : ""}
        ECS_ENABLE_TASK_IAM_ROLE=true
        ${var.ecs.service.ec2.architecture == "gpu" ? "ECS_ENABLE_GPU_SUPPORT=true" : ""}
        ${var.ecs.service.ec2.architecture == "gpu" ? "ECS_NVIDIA_RUNTIME=nvidia" : ""}
        ECS_RESERVED_MEMORY=100
        EOF
      EOT
  }
}

#------------------------
#     EC2 autoscaler
#------------------------
// TODO: support multiple instance_types
module "asg" {
  source = "../asg"

  for_each = local.asgs

  name          = each.key
  instance_type = each.value.instance_type
  chip_type     = var.ecs.service.ec2.chip_type

  capacity_provider = {
    weight = each.value.capacity.weight
  }
  capacity_weight_total = sum([for capacity in var.ecs.service.ec2.capacities : capacity.weight])
  key_name              = var.ecs.service.ec2.key_name
  instance_refresh      = var.ecs.service.ec2.asg.instance_refresh
  use_spot              = each.value.capacity.type == "ON_DEMAND" ? false : true

  image_id                 = local.image_id
  user_data_base64         = base64encode(local.user_data[each.value.capacity.type])
  port_mapping             = "dynamic"
  layer7_to_layer4_mapping = local.layer7_to_layer4_mapping
  traffics                 = local.traffics
  target_group_arns        = module.elb.target_group.arns
  source_security_group_id = module.elb.security_group.id

  vpc           = var.vpc
  min_count     = ceil(var.ecs.service.task.min_size / length(local.asgs))
  max_count     = ceil(var.ecs.service.task.max_size / length(local.asgs))
  desired_count = ceil(var.ecs.service.task.desired_size / length(local.asgs))

  tags = var.tags
}

resource "aws_autoscaling_attachment" "ecs" {
  for_each               = module.asg
  autoscaling_group_name = each.value.autoscaling.group_name
  lb_target_group_arn    = element(module.elb.target_group.arns, 0)
}

# group notification
# resource "aws_autoscaling_notification" "webserver_asg_notifications" {
#   group_names = [
#     aws_autoscaling_group.webserver_asg.name,
#   ]
#   notifications = [
#     "autoscaling:EC2_INSTANCE_LAUNCH",
#     "autoscaling:EC2_INSTANCE_TERMINATE",
#     "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
#     "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
#   ]
#   topic_arn = aws_sns_topic.webserver_topic.arn
# }
# resource "aws_sns_topic" "webserver_topic" {
#   name = "webserver_topic"
# }
