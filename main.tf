locals {
  tags = merge(var.tags, { VpcId = var.vpc.id })

  listeners = { for container in var.orchestrator.group.deployment.containers : container.name => [
    for traffic in container.traffics : merge(traffic.listener, {
      port = coalesce(
        traffic.listener.port,
        traffic.listener.protocol == "http" ? 80 : null,
        traffic.listener.protocol == "https" ? 443 : null,
        traffic.listener.protocol_version == "grpc" ? 443 : null,
      )
      protocol_version = coalesce(
        traffic.listener.protocol_version,
        traffic.listener.protocol == "http" ? "http1" : null,
        traffic.listener.protocol == "https" ? "http1" : null,
        traffic.target.protocol_version == "grpc" ? "grpc" : null,
      )
    })
    ]
  }

  targets = { for container in var.orchestrator.group.deployment.containers : container.name => [
    for index, traffic in container.traffics : merge(traffic.target, {
      protocol = coalesce(
        traffic.target.protocol,
        local.listeners[container.name][index].protocol,
      )
      protocol_version = coalesce(
        traffic.target.protocol_version,
        traffic.target.protocol == "http" ? "http1" : null,
        traffic.target.protocol == "https" ? "http1" : null,
        local.listeners[container.name][index].protocol_version,
      )
      health_check_path = coalesce(
        traffic.target.health_check_path,
        "/",
      )
    })]
  }

}

module "ecs" {
  source = "./modules/ecs"

  name    = var.name
  vpc     = local.vpc
  route53 = var.route53
  bucket_env = var.bucket_env != null ? {
    name     = join("-", [var.name, "env"])
    file_key = var.bucket_env.file_key
  } : null
  ecs = {
    service = {
      name = var.orchestrator.group.name
      task = merge(
        var.orchestrator.group.deployment,
        {
          cpu    = var.orchestrator.group.fargate != null ? var.orchestrator.group.deployment.cpu : null
          memory = var.orchestrator.group.fargate != null ? var.orchestrator.group.deployment.memory : null
          containers = [
            for container in var.orchestrator.group.deployment.containers :
            merge(
              container,
              {
                cpu         = coalesce(container.cpu, try(local.instances[var.orchestrator.group.ec2.instance_types[0]].cpu, null))
                memory      = coalesce(container.memory, try(local.instances[var.orchestrator.group.ec2.instance_types[0]].memory_available, null))
                device_idxs = coalesce(container.device_idxs, try(range(local.instances[var.orchestrator.group.ec2.instance_types[0]].device_count), null), [])
                traffics = [for index, traffic in container.traffics : {
                  listener = local.listeners[container.name][index]
                  target   = local.targets[container.name][index]
                }]
              },
            )
          ]
        },
      )
      ec2 = var.orchestrator.group.ec2 != null ? {
        key_name       = var.orchestrator.group.ec2.key_name
        instance_types = var.orchestrator.group.ec2.instance_types
        os             = var.orchestrator.group.ec2.os
        os_version     = var.orchestrator.group.ec2.os_version
        capacities     = var.orchestrator.group.ec2.capacities
        architecture   = values(local.instances)[0].architecture
        chip_type      = values(local.instances)[0].chip_type
      } : null
      fargate = var.orchestrator.group.fargate != null ? {
        os           = var.orchestrator.group.fargate.os
        architecture = var.orchestrator.group.fargate.architecture
        capacities   = var.orchestrator.group.fargate.capacities
      } : null
    }
  }

  tags = local.tags
}

# module "eks" {
#   source = "./modules/eks"

#   for_each = var.orchestrator.eks != null ? { "${local.name}" = {} } : {}

#   name     = local.name
#   vpc      = local.vpc
#   route53  = var.route53
#   traffics = var.traffics
#   bucket_env = try({
#     name     = one(values(module.bucket_env)).bucket.name
#     file_key = var.bucket_env.file_key
#   }, null)
#   eks = {
#     create          = var.orchestrator.eks != null ? true : false
#     cluster_version = var.orchestrator.eks.cluster_version
#     group = {
#       name       = var.orchestrator.group.name
#       deployment = var.orchestrator.group.deployment
#       ec2 = {
#         key_name       = var.orchestrator.group.ec2.key_name
#         instance_types = var.orchestrator.group.ec2.instance_types
#         os             = var.orchestrator.group.ec2.os
#         os_version     = var.orchestrator.group.ec2.os_version
#         capacities     = var.orchestrator.group.ec2.capacities

#         architecture   = one(values(local.instances_specs)).architecture
#         chip_type = one(values(local.instances_specs)).chip_type
#       }
#       fargate = var.orchestrator.group.fargate
#     }
#   }

#   tags = local.tags
# }

# ------------------------
#     Bucket env
# ------------------------
module "bucket_env" {
  source = "./modules/bucket"

  for_each = var.bucket_env != null ? { 0 = {} } : {}

  name          = var.name
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning
  encryption = {
    enable = true
  }

  tags = local.tags
}

resource "aws_s3_object" "env" {
  for_each = var.bucket_env != null ? { 0 = {} } : {}

  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env[each.key].bucket.name
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
