data "aws_ec2_instance_type" "current" {
  for_each = { for instance_type in try(var.orchestrator.group.ec2.instance_types, []) : instance_type => {} }

  instance_type = each.key
}


locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html
  # https://docs.aws.amazon.com/cli/latest/reference/ecs/describe-container-instances.html

  instance_datas = {
    for instance_type in try(var.orchestrator.group.ec2.instance_types, []) :
    instance_type => regex("^(?P<instance_family>\\w+)(?P<instance_generation>\\d)(?P<processor_family>\\w?)(?P<additional_capability>\\w?)\\.(?P<instance_size>\\w+)$", instance_type)
  }

  instance_chip_types = {
    for instance_type, instance_data in local.instance_datas :
    instance_type => contains(["p", "g"], instance_data.instance_family) ? "gpu" : (
      contains(["inf", "trn"], instance_data.instance_family) ? "inf" : "cpu"
    )
  }

  instance_specs = {
    for instance in data.aws_ec2_instance_type.current : instance.id => {
      cpu              = instance.default_vcpus * 1024
      memory           = instance.memory_size
      memory_available = floor(instance.memory_size * 0.9) # leaves some overhead for ECS
      device_count = coalesce(
        try(one(instance.inference_accelerators).count, null),
        try(one(instance.gpus).count, null),
        0,
      )
      architecture = one(instance.supported_architectures)
    }
  }

  instances = {
    for instance_type, instance_data in local.instance_datas : instance_type => {
      instance_family       = instance_data.instance_family
      instance_generation   = instance_data.instance_generation
      processor_family      = instance_data.processor_family
      additional_capability = instance_data.additional_capability
      instance_size         = instance_data.instance_size
      architecture          = local.instance_specs[instance_type].architecture
      chip_type             = local.instance_chip_types[instance_type]
      cpu                   = local.instance_specs[instance_type].cpu
      memory                = local.instance_specs[instance_type].memory
      memory_available      = local.instance_specs[instance_type].memory_available
      device_count          = local.instance_specs[instance_type].device_count
    }
  }
}

resource "null_resource" "instances" {
  for_each = var.orchestrator.group.ec2 != null ? { 0 = {} } : {}

  lifecycle {
    precondition {
      condition     = length(distinct([for _, instance_specs in local.instances : instance_specs.architecture])) == 1
      error_message = "instances need to have the same architecture: ${jsonencode({ for instance_type, instance_specs in local.instances : instance_type => instance_specs.architecture })}"
    }

    precondition {
      condition     = alltrue([for instance_type in var.orchestrator.group.ec2.instance_types : contains(keys(local.instance_specs), instance_type)])
      error_message = <<EOF
only supported instance types are: ${jsonencode(keys(local.instances))}
got: ${jsonencode(var.orchestrator.group.ec2.instance_types)}
EOF
    }
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
# https://aws.amazon.com/ec2/instance-types/
resource "null_resource" "instance" {
  for_each = { for instance_type, instance_specs in local.instances : instance_type => instance_specs }

  lifecycle {
    precondition {
      condition     = contains(["inf", "gpu", "cpu"], each.value.chip_type) ? length(var.orchestrator.group.ec2.instance_types) == 1 : true
      error_message = "ec2 inf/gpu/cpu instance types must contain only one element, got ${jsonencode(var.orchestrator.group.ec2.instance_types)}"
    }

    precondition {
      condition     = var.orchestrator.group.ec2.os == "linux" ? contains(["x86_64", "arm64", "gpu", "inf"], each.value.architecture) : false
      error_message = "EC2 architecture must for one of linux:[x86_64, arm64, gpu, inf]"
    }

    precondition {
      condition     = contains(["inf", "gpu"], each.value.chip_type) ? length(var.orchestrator.group.ec2.instance_types) == 1 : true
      error_message = "ec2 inf/gpu instance types must contain only one element, got ${jsonencode(var.orchestrator.group.ec2.instance_types)}"
    }

    precondition {
      condition     = contains(["gpu", "inf"], each.value.chip_type) ? alltrue([for idx in flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.device_idxs, [])]) : idx > 0 && idx < local.instances[var.orchestrator.group.ec2.instance_types[0]].device_count]) : true
      error_message = <<EOF
ec2 gpu/inf containers must have available device indexes, got: ${jsonencode(sort(flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.device_idxs, [])])))}
available: ${jsonencode(range(local.instances[var.orchestrator.group.ec2.instance_types[0]].device_count))}
EOF
    }
  }
}

data "aws_ec2_instance_type_offerings" "instance_region" {
  for_each = var.orchestrator.group.ec2 != null ? { 0 = {} } : {}

  filter {
    name   = "instance-type"
    values = [for instance_type in var.orchestrator.group.ec2.instance_types : instance_type]
  }

  filter {
    name   = "location"
    values = [local.region_name]
  }

  location_type = "region"
}

resource "null_resource" "instance_region" {
  for_each = var.orchestrator.group.ec2 != null ? { 0 = {} } : {}

  lifecycle {
    postcondition {
      condition     = sort(distinct([for instance_type in var.orchestrator.group.ec2.instance_types : instance_type])) == sort(distinct(data.aws_ec2_instance_type_offerings.instance_region[0].instance_types))
      error_message = <<EOF
ec2 instances type are not all available in the region
want::
${jsonencode(sort([for instance_type in var.orchestrator.group.ec2.instance_types : instance_type]))}
region::
${jsonencode(sort(data.aws_ec2_instance_type_offerings.instance_region[0].instance_types))}
EOF
    }
  }
}
