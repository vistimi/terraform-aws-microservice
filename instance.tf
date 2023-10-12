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
      contains(["t", "m", "c", "z", "u-", "x", "r", "dl", "trn", "f", "vt", "i", "d", "h", "hpc"], instance_data.instance_family) && contains(["", "i"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "x86_64" : (
        contains(["t", "m", "c", "r", "i", "Im", "Is", "hpc"], instance_data.instance_family) && contains(["a", "g"], substr(instance_data.instance_prefix, length(instance_data.instance_family) + 1, 1)) ? "arm64" : (
          contains(["p", "g"], instance_data.instance_family) ? "gpu" : (
            contains(["inf"], instance_data.instance_family) ? "inf" : null
          )
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
      processor_type = local.instances_arch[instance_type] == "gpu" ? "gpu" : (
        local.instances_arch[instance_type] == "inf" ? "inf" : "cpu"
      )
    }
  }

  instances_properties = {
    // cpu
    "t3.small" = {
      cpu              = 2048
      memory           = 2048
      memory_available = 1900
    }
    "t3.medium" = {
      cpu              = 2048
      memory           = 4096
      memory_available = 3820
    }

    // gpu
    "g4dn.xlarge" = {
      cpu              = 4096
      gpu              = 1
      memory           = 16384
      memory_available = 15730
    }

    # trainium
    # "trn1.2xlarge" = {
    #   cpu              = 8192
    #   memory           = 32768
    #   memory_available = 32768 // TODO: not tested yet
    #   device_paths     = ["/dev/neuron0"]
    # }
    # "trn1.2xlarge" = {
    #   cpu              = 131072
    #   memory           = 524288
    #   memory_available = 524288 // TODO: not tested yet
    #   device_paths     = ["/dev/neuron0", "/dev/neuron1", "/dev/neuron2", "/dev/neuron3", "/dev/neuron4", "/dev/neuron5", "/dev/neuron6", "/dev/neuron7", "/dev/neuron8", "/dev/neuron9", "/dev/neuron10", "/dev/neuron11", "/dev/neuron12", "/dev/neuron13", "/dev/neuron14", "/dev/neuron15"]
    # }

    // inferentia
    "inf1.xlarge" = {
      cpu              = 4096
      memory           = 8192
      memory_available = 7660
      device_paths     = ["/dev/neuron0"]
    }
    "inf1.2xlarge" = {
      cpu              = 8192
      memory           = 16384
      memory_available = 15560
      device_paths     = ["/dev/neuron0"]
    }
    "inf1.6xlarge" = {
      cpu              = 24576
      memory           = 49152
      memory_available = 49152 // TODO: not tested yet
      device_paths     = ["/dev/neuron0", "/dev/neuron1", "/dev/neuron2", "/dev/neuron3"]
    }
    "inf2.xlarge" = {
      cpu              = 8192
      memory           = 16384
      memory_available = 16384 // TODO: not tested yet
      device_paths     = ["/dev/neuron0"]
    }
    "inf2.8xlarge" = {
      cpu              = 32768
      memory           = 131072
      memory_available = 131072 // TODO: not tested yet
      device_paths     = ["/dev/neuron0"]
    }
  }
}

resource "null_resource" "instances" {
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
      condition     = contains(["inf", "gpu", "cpu"], each.value.processor_type) ? length(var.orchestrator.group.ec2.instance_types) == 1 : true
      error_message = "ec2 inf/gpu/cpu instance types must contain only one element, got ${jsonencode(var.orchestrator.group.ec2.instance_types)}"
    }

    precondition {
      condition     = var.orchestrator.group.ec2.os == "linux" ? contains(["x86_64", "arm64", "gpu", "inf"], each.value.architecture) : false
      error_message = "EC2 architecture must for one of linux:[x86_64, arm64, gpu, inf]"
    }

    precondition {
      condition     = each.value.architecture == "gpu" ? var.orchestrator.group.container.gpu != null : true
      error_message = "EC2 gpu must have a task definition gpu number"
    }

    precondition {
      condition     = contains(["inf", "gpu"], each.value.processor_type) ? length(var.orchestrator.group.ec2.instance_types) == 1 : true
      error_message = "ec2 inf/gpu instance types must contain only one element, got ${jsonencode(var.orchestrator.group.ec2.instance_types)}"
    }

    precondition {
      condition     = contains(["gpu"], each.value.processor_type) ? alltrue([for idx in flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.devices_idx, [])]) : idx > 0 && idx < length(local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].gpu)]) : true
      error_message = <<EOF
ec2 gpu containers must have available device indexes, got: ${jsonencode(sort(flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.devices_idx, [])])))}
available: ${jsonencode(range(try(local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].gpu, 0)))}
EOF
    }

    precondition {
      condition     = contains(["inf"], each.value.processor_type) ? alltrue([for idx in flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.devices_idx, [])]) : idx > 0 && idx < length(local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].device_paths)]) : true
      error_message = <<EOF
ec2 inf containers must have available device indexes, got: ${jsonencode(sort(flatten([for container in var.orchestrator.group.deployment.containers : coalesce(container.devices_idx, [])])))}
available: ${jsonencode(range(length(try(local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].device_paths, []))))}
EOF
    }
  }
}
