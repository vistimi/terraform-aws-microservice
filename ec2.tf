data "aws_ec2_instance_type" "current" {
  for_each = { for instance_type in try(var.orchestrator.group.ec2.instance_types, []) : instance_type => {} }

  instance_type = each.key
}


locals {
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/memory-management.html
  # https://docs.aws.amazon.com/cli/latest/reference/ecs/describe-container-instances.html

  instances = {
    for instance_type in try(var.orchestrator.group.ec2.instance_types, []) :
    instance_type => {
      instance_prefix = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).prefix
      instance_size   = regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).size
      instance_family = try(one(regex("(mac|u-|dl|trn|inf|vt|Im|Is|hpc)", regex("^(?P<prefix>\\w+)\\.(?P<size>\\w+)$", instance_type).prefix)), substr(instance_type, 0, 1))
    }
  }

  instances_arch = {
    for instance_type, instance_data in local.instances :
    instance_type => (
      contains(["", "i"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "x86_64" : (
        contains(["a", "g"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "arm64" : null
      )
    )

    # (
    #   contains(["t", "m", "c", "z", "u-", "x", "r", "dl", "trn", "f", "vt", "i", "d", "h", "hpc"], instance_data.instance_family) && contains(["", "i"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "x86_64" : (
    #     contains(["t", "m", "c", "r", "i", "Im", "Is", "hpc"], instance_data.instance_family) && contains(["a", "g"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "arm64" : (
    #       contains(["p", "g"], instance_data.instance_family) ? "gpu" : (
    #         contains(["inf"], instance_data.instance_family) ? "inf" : null
    #       )
    #     )
    #   )
    # )
  }

  cpu_x86_64 = ["t", "m", "c", "z", "u-", "x", "r", "dl", "f", "vt", "i", "d", "h", "hpc"]
  cpu_arm64  = ["t", "m", "c", "r", "i", "Im", "Is", "hpc"]
  instances_chip_type = {
    for instance_type, instance_data in local.instances :
    instance_type => (
      contains(distinct(concat(local.cpu_x86_64, local.cpu_arm64)), instance_data.instance_family) ? "cpu" : (
        contains(["p", "g"], instance_data.instance_family) ? "gpu" : (
          contains(["inf", "trn"], instance_data.instance_family) ? "inf" : null
        )
      )
    )
  }

  // TODO: add support for mac
  // gpu and inf both have cpus with either arm or x86 but the configuration doesn't require that to be specified
  instances_specs = {
    for instance_type, instance_data in local.instances : instance_type => {
      family                = instance_data.instance_family
      generation            = substr(instance_data.instance_prefix, length(instance_data.instance_family) + 0, 1)
      architecture          = local.instances_arch[instance_type]
      processor_family      = substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)
      additional_capability = substr(instance_data.instance_prefix, length(instance_data.instance_family) + 2, -1)
      instance_size         = instance_data.instance_size
      chip_type             = local.instances_chip_type[instance_type]
    }
  }

  instances_properties = {
    for instance in data.aws_ec2_instance_type.current : instance.id => {
      cpu              = instance.default_vcpus * 1024
      memory           = instance.memory_size
      memory_available = floor(instance.memory_size * 0.9) # leaves some overhead for ECS
      device_count = coalesce(
        try(one(instance.inference_accelerators).count, null),
        try(one(instance.gpus).count, null),
        0,
      )
    }
  }
}

resource "null_resource" "instances" {
  for_each = var.orchestrator.group.ec2 != null ? { 0 = {} } : {}

  lifecycle {
    precondition {
      condition     = length(distinct([for _, instance_specs in local.instances_specs : instance_specs.architecture])) == 1
      error_message = "instances need to have the same architecture: ${jsonencode({ for instance_type, instance_specs in local.instances_specs : instance_type => instance_specs.architecture })}"
    }

    precondition {
      condition     = alltrue([for instance_type in var.orchestrator.group.ec2.instance_types : contains(keys(local.instances_properties), instance_type)])
      error_message = <<EOF
only supported instance types are: ${jsonencode(keys(local.instances_properties))}
got: ${jsonencode(var.orchestrator.group.ec2.instance_types)}
EOF
    }
  }
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
# https://aws.amazon.com/ec2/instance-types/
resource "null_resource" "instance" {
  for_each = { for instance_type, instance_specs in local.instances_specs : instance_type => instance_specs }

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
      condition     = contains(["gpu", "inf"], each.value.chip_type) ? alltrue([for idx in flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.device_idxs, [])]) : idx > 0 && idx < local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].device_count]) : true
      error_message = <<EOF
ec2 gpu/inf containers must have available device indexes, got: ${jsonencode(sort(flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.device_idxs, [])])))}
available: ${jsonencode(range(local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].device_count))}
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
