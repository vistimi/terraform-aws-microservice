output "cluster" {
  value = {
    arn                        = module.eks.cluster_arn
    certificate_authority_data = module.eks.cluster_certificate_authority_data
    endpoint                   = module.eks.cluster_endpoint
    id                         = module.eks.cluster_id
    name                       = module.eks.cluster_name
    oidc_issuer_url            = module.eks.cluster_oidc_issuer_url
    version                    = module.eks.cluster_version
    platform_version           = module.eks.cluster_platform_version
    status                     = module.eks.cluster_status
    primary_security_group_id  = module.eks.cluster_primary_security_group_id

    addons = module.eks.cluster_addons

    identity_providers = module.eks.cluster_identity_providers
  }
}

output "kms_key" {
  value = {
    arn    = module.eks.kms_key_arn
    id     = module.eks.kms_key_id
    policy = module.eks.kms_key_policy
  }
}

output "cluster_security_group" {
  value = {
    arn = module.eks.cluster_security_group_arn
    id  = module.eks.cluster_security_group_id
  }
}

output "node_security_group" {
  value = {
    arn = module.eks.node_security_group_arn
    id  = module.eks.node_security_group_id
  }
}

output "oidc_provider" {
  value = {
    url         = module.eks.oidc_provider
    arn         = module.eks.oidc_provider_arn
    certificate = module.eks.cluster_tls_certificate_sha1_fingerprint
  }
}

output "cluster_iam_role" {
  value = {
    name      = module.eks.cluster_iam_role_name
    arn       = module.eks.cluster_iam_role_arn
    unique_id = module.eks.cluster_iam_role_unique_id
  }
}

output "cloudwatch_log_group" {
  value = {
    name = module.eks.cloudwatch_log_group_name
    arn  = module.eks.cloudwatch_log_group_arn
  }
}

output "fargate_profiles" {
  value = module.eks.fargate_profiles
}

output "eks_managed_node_groups" {
  value = {
    attributes              = module.eks.eks_managed_node_groups
    autoscaling_group_names = module.eks.eks_managed_node_groups_autoscaling_group_names
  }
}

output "aws_auth_configmap_yaml" {
  value = module.eks.aws_auth_configmap_yaml
}
