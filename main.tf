locals {
  tags = merge(var.tags, { VpcId = "${var.vpc.id}" })
}

module "ecs" {
  source = "./modules/ecs"

  name     = var.name
  vpc      = var.vpc
  route53  = var.route53
  traffics = var.traffics
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
          cpu    = local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].cpu
          memory = local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].memory_available
          containers = [
            for container in var.orchestrator.group.deployment.containers :
            merge(
              container,
              {
                cpu         = coalesce(container.cpu, local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].cpu)
                memory      = coalesce(container.memory, local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].memory_available)
                devices_idx = coalesce(container.devices_idx, try(range(length(local.instances_properties[var.orchestrator.group.ec2.instance_types[0]].device_paths)), []))
              },
            )
          ]
        },
      )
      ec2 = {
        key_name       = var.orchestrator.group.ec2.key_name
        instance_types = var.orchestrator.group.ec2.instance_types
        os             = var.orchestrator.group.ec2.os
        os_version     = var.orchestrator.group.ec2.os_version
        capacities     = var.orchestrator.group.ec2.capacities

        architecture   = one(values(local.instances_specs)).architecture
        processor_type = one(values(local.instances_specs)).processor_type
      }
      fargate = var.orchestrator.group.fargate
    }
  }

  tags = local.tags
}

# module "eks" {
#   source = "./modules/eks"

#   for_each = var.orchestrator.eks != null ? { "${var.name}" = {} } : {}

#   name     = var.name
#   vpc      = var.vpc
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
#         processor_type = one(values(local.instances_specs)).processor_type
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

  for_each = var.bucket_env != null ? { "${var.name}" = {} } : {}

  name          = var.name
  force_destroy = var.bucket_env.force_destroy
  versioning    = var.bucket_env.versioning
  encryption = {
    enable = true
  }

  tags = local.tags
}

resource "aws_s3_object" "env" {
  for_each = var.bucket_env != null ? { "${var.name}" = {} } : {}

  key                    = var.bucket_env.file_key
  bucket                 = module.bucket_env[each.key].bucket.name
  source                 = var.bucket_env.file_path
  server_side_encryption = "aws:kms"
}
