module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv6   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.tags
}

# module "ssh_sg" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "5.0.0"

#   description = "SSH security group"
#   vpc_id      = var.vpc.id
#   name        = var.name

#   // accept SSH if key
#   ingress_with_cidr_blocks = var.eks.ec2 != null ? [
#     {
#       from_port   = 22
#       to_port     = 22
#       protocol    = "tcp"
#       description = "SSH"
#       cidr_blocks = "0.0.0.0/0"
#     },
#   ] : []
#   egress_rules = ["all-all"]

#   tags = var.tags
# }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.16.0"

  create                         = var.eks.create
  cluster_name                   = var.name
  cluster_version                = var.eks.cluster_version
  cluster_endpoint_public_access = true
  cluster_addons = {
    coredns = var.eks.group.fargate != null ? {
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
      } : {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = var.eks.group.ec2 != null ? {
      most_recent = true
      # before_compute           = true
      # service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      # configuration_values = jsonencode({
      #   env = {
      #     # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
      #     ENABLE_PREFIX_DELEGATION = "true"
      #     WARM_PREFIX_TARGET       = "1"
      #   }
      # })
      } : {
      most_recent = true
    }
  }

  vpc_id                   = var.vpc.id
  subnet_ids               = local.tier_subnet_ids
  control_plane_subnet_ids = local.intra_subnet_ids

  # Extend cluster security group rules
  # cluster_security_group_additional_rules = {
  #   ingress_nodes_ephemeral_ports_tcp = {
  #     description                = "Nodes on ephemeral ports"
  #     protocol                   = "tcp"
  #     from_port                  = 1025
  #     to_port                    = 65535
  #     type                       = "ingress"
  #     source_node_security_group = true
  #   }
  # }

  # Extend node-to-node security group rules
  # node_security_group_additional_rules = {
  #   ingress_self_all = {
  #     description = "Node to node all ports/protocols"
  #     protocol    = "-1"
  #     from_port   = 0
  #     to_port     = 0
  #     type        = "ingress"
  #     self        = true
  #   }
  # }

  eks_managed_node_groups = {
    for capacity in var.eks.group.ec2.capacities : "${var.name}-${capacity.type}" => {
      use_custom_launch_template = false
      description                = "EKS managed node group example launch template"

      # remote_access = try({
      #   ec2_ssh_key               = var.eks.group.ec2.key_name
      #   source_security_group_ids = [module.ssh_sg[key].security_group_id]
      # }, null)

      subnet_ids = local.tier_subnet_ids
      ami_id     = local.image_id
      # disk_size  = 50

      min_size     = var.eks.group.deployment.min_size
      max_size     = var.eks.group.deployment.max_size
      desired_size = var.eks.group.deployment.desired_size

      instance_types = var.eks.group.ec2.instance_types
      capacity_type  = capacity.type

      # For the pod to be eligible to run on a node, the node must have each of the indicated key-value pairs as labels
      # labels = {
      #   GithubRepo = "terraform-aws-eks"
      #   GithubOrg  = "terraform-aws-modules"
      # }

      # Taints and tolerations work together to ensure that Pods aren't scheduled onto inappropriate nodes
      # taints = [
      #   # {
      #   #   key    = "dedicated"
      #   #   value  = "gpuGroup"
      #   #   effect = "NO_SCHEDULE"
      #   # }
      # ]

      # update_config = {
      #   max_unavailable_percentage = var.eks.group.deployment_maximum_percent
      # }


      ebs_optimized           = false
      disable_api_termination = false
      enable_monitoring       = true

      # block_device_mappings = {
      #   xvda = {
      #     device_name = "/dev/xvda"
      #     ebs = {
      #       volume_size           = 75
      #       volume_type           = "gp3"
      #       iops                  = 3000
      #       throughput            = 150
      #       encrypted             = true
      #       kms_key_id            = module.ebs_kms_key.key_arn
      #       delete_on_termination = true
      #     }
      #   }
      # }

      pre_bootstrap_user_data = <<-EOT
        echo "registering kubelet"
      EOT

      post_bootstrap_user_data = <<-EOT
        echo "deregistering kubelet"
      EOT

      # metadata_options = {
      #   http_endpoint               = "enabled"
      #   http_tokens                 = "required"
      #   http_put_response_hop_limit = 2
      #   instance_metadata_tags      = "disabled"
      # }

      create_iam_role          = true
      iam_role_name            = "eks-managed-node-group-complete-example"
      iam_role_use_name_prefix = false
      iam_role_description     = "EKS managed node group complete example role"
      iam_role_tags            = var.tags
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" # ECR read
        # additional                         = aws_iam_policy.node_additional.arn
      }

      # schedules = {
      #   scale-up = {
      #     min_size     = 2
      #     max_size     = "-1" # Retains current max size
      #     desired_size = 2
      #     start_time   = "2023-03-05T00:00:00Z"
      #     end_time     = "2024-03-05T00:00:00Z"
      #     timezone     = "Etc/GMT+0"
      #     recurrence   = "0 0 * * *"
      #   },
      #   scale-down = {
      #     min_size     = 0
      #     max_size     = "-1" # Retains current max size
      #     desired_size = 0
      #     start_time   = "2023-03-05T12:00:00Z"
      #     end_time     = "2024-03-05T12:00:00Z"
      #     timezone     = "Etc/GMT+0"
      #     recurrence   = "0 12 * * *"
      #   }
      # }

      tags = var.tags
    }
  }

  #   # Fargate Profile(s)
  # fargate_profiles = {
  #     default = {
  #       name = "default"
  #       selectors = [
  #         {
  #           namespace = "kube-system"
  #           labels = {
  #             k8s-app = "kube-dns"
  #           }
  #         },
  #         {
  #           namespace = "default"
  #         }
  #       ]

  #       tags = {
  #         Owner = "test"
  #       }

  #       timeouts = {
  #         create = "20m"
  #         delete = "20m"
  #       }
  #     }

  # aws-auth configmap
  manage_aws_auth_configmap = true
  # create_aws_auth_configmap = true
  aws_auth_users = [
    {
      userarn  = data.aws_caller_identity.current.arn
      username = regex("^arn:aws:iam::\\w+:user\\/(?P<user_name>\\w+)$", data.aws_caller_identity.current.arn).user_name
      groups   = ["system:masters"]
    },
  ]
  # aws_auth_accounts = [local.account_id]

  tags = var.tags
}

# resource "kubectl_manifest" "current" {
#   yaml_body = <<YAML
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: test-ingress
#   annotations:
#     nginx.ingress.kubernetes.io/rewrite-target: /
#     azure/frontdoor: enabled
# spec:
#   rules:
#   - http:
#       paths:
#       - path: /testpath
#         pathType: "Prefix"
#         backend:
#           serviceName: test
#           servicePort: 80
# YAML
# }

# resource "kubectl_manifest" "deployment" {
#   provider = kubectl

#   yaml_body = <<YAML
# apiVersion: apps/v1
# kind: Deployment
# metadata:
#   name: microservice-deployment-non-tainted
# spec:
#   replicas: 1
#   selector:
#     matchLabels:
#       name: ${var.name}-container
#   template:
#     metadata:
#       labels:
#         name: ${var.name}-container
#     spec:
#       containers:
#         - name: ${var.name}-container
#           image: hello-world
#           ports:
#             - containerPort: 80
# YAML

#   depends_on = [module.eks]
# }

resource "aws_ec2_tag" "tier" {
  for_each = { for subnet_id in local.tier_subnet_ids : subnet_id => {} }

  resource_id = each.key
  key         = "kubernetes.io/role/elb"
  value       = 1
}
resource "aws_ec2_tag" "intra" {
  for_each = { for subnet_id in local.intra_subnet_ids : subnet_id => {} }

  resource_id = each.key
  key         = "kubernetes.io/role/control-plane"
  value       = 1
}


locals {
  # We need to lookup K8s taint effect from the AWS API value
  taint_effects = {
    NO_SCHEDULE        = "NoSchedule"
    NO_EXECUTE         = "NoExecute"
    PREFER_NO_SCHEDULE = "PreferNoSchedule"
  }

  cluster_autoscaler_label_tags = merge([
    for name, group in module.eks.eks_managed_node_groups : {
      for label_name, label_value in coalesce(group.node_group_labels, {}) : "${name}|label|${label_name}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0],
        key               = "k8s.io/cluster-autoscaler/node-template/label/${label_name}",
        value             = label_value,
      }
    }
  ]...)

  cluster_autoscaler_taint_tags = merge([
    for name, group in module.eks.eks_managed_node_groups : {
      for taint in coalesce(group.node_group_taints, []) : "${name}|taint|${taint.key}" => {
        autoscaling_group = group.node_group_autoscaling_group_names[0],
        key               = "k8s.io/cluster-autoscaler/node-template/taint/${taint.key}"
        value             = "${taint.value}:${local.taint_effects[taint.effect]}"
      }
    }
  ]...)

  cluster_autoscaler_asg_tags = merge(local.cluster_autoscaler_label_tags, local.cluster_autoscaler_taint_tags)
}

resource "aws_autoscaling_group_tag" "cluster_autoscaler_label_tags" {
  for_each = local.cluster_autoscaler_asg_tags

  autoscaling_group_name = each.value.autoscaling_group

  tag {
    key   = each.value.key
    value = each.value.value

    propagate_at_launch = false
  }
}
