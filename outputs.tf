output "ecs" {
  value = module.ecs
}

# output "eks" {
#   value = one(values(module.eks))
# }

output "env" {
  value = module.bucket_env
}

output "instances_specs" {
  value = local.instances_specs
}
