locals {
  fargate_capacity_provider_keys = {
    ON_DEMAND = "FARGATE"
    SPOT      = "FARGATE_SPOT"
  }

  container_targets = {
    for container in var.ecs.service.task.containers : container.name => distinct(flatten([for traffic in container.traffics : {
      port             = traffic.target.port
      protocol         = traffic.target.protocol
      protocol_version = traffic.target.protocol_version
    }]))
  }
}

resource "null_resource" "container_targets" {
  lifecycle {
    precondition {
      condition     = alltrue([for container in local.container_targets : length([for target in container : target.port]) == length(distinct([for target in container : target.port]))])
      error_message = "Multiple tragets with the same port is used (make sure that all traffics points toward same protocol and protocol version): ${jsonencode(local.container_targets)}"
    }
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.2.2"

  cluster_name = var.name

  # capacity providers
  default_capacity_provider_use_fargate = var.ecs.service.ec2 != null ? false : true
  fargate_capacity_providers = try({
    for capacity in var.ecs.service.fargate.capacities :
    local.fargate_capacity_provider_keys[capacity.type] => {
      default_capacity_provider_strategy = {
        weight = capacity.weight
        base   = capacity.base
      }
    }
  }, {})
  autoscaling_capacity_providers = {
    for capacity in try(var.ecs.service.ec2.capacities, []) :
    "${var.name}-${capacity.type}" => {
      name                   = "${var.name}-${capacity.type}"
      auto_scaling_group_arn = one(values(module.asg)).autoscaling.group_arn
      managed_scaling = {
        // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-quotas.html
        maximum_scaling_step_size = capacity.maximum_scaling_step_size == null ? max(min(ceil((var.ecs.service.task.max_size - var.ecs.service.task.min_size) / 3), 10), 1) : capacity.maximum_scaling_step_size
        minimum_scaling_step_size = capacity.minimum_scaling_step_size == null ? max(min(floor((var.ecs.service.task.max_size - var.ecs.service.task.min_size) / 10), 10), 1) : capacity.minimum_scaling_step_size
        target_capacity           = capacity.target_capacity_cpu_percent # utilization for the capacity provider
        status                    = "ENABLED"
        instance_warmup_period    = 300
        default_capacity_provider_strategy = {
          base   = capacity.base
          weight = capacity.weight
        }
      }
      managed_termination_protection = "DISABLED"
    }
  }

  # TODO: one service per instance type
  services = {
    "${var.name}-${var.ecs.service.name}" = {
      #------------
      # Service
      #------------
      wait_for_steady_state      = true
      force_new_deployment       = true
      launch_type                = var.ecs.service.ec2 != null ? "EC2" : "FARGATE"
      enable_autoscaling         = true
      autoscaling_min_capacity   = var.ecs.service.task.min_size
      desired_count              = var.ecs.service.task.desired_size
      autoscaling_max_capacity   = var.ecs.service.task.max_size
      deployment_maximum_percent = var.ecs.service.task.maximum_percent // max % tasks running required
      # deployment_minimum_healthy_percent = 66                                   // min % tasks running required
      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      # network awsvpc for fargate
      subnets          = var.ecs.service.ec2 != null ? null : var.vpc.subnet_tier_ids
      assign_public_ip = var.ecs.service.ec2 != null ? null : true // if private subnets, use NAT

      load_balancer = merge(
        # keys need to be known at build time
        [
          for container in var.ecs.service.task.containers : {
            for traffic in container.traffics :
            join("-", [var.name, container.name, traffic.listener.protocol, traffic.listener.port, "to", traffic.target.protocol, traffic.target.port]) => {
              target_group_arn = module.elb.target_group.arns[
                [for index, target in distinct(flatten([for container in var.ecs.service.task.containers : [for traffic in container.traffics : {
                  port = traffic.target.port
                }]])) : index if target.port == traffic.target.port][0]
              ]
              container_name = "${var.name}-${container.name}"
              container_port = traffic.target.port
            }
          }
        ]...
      )


      # security group
      subnet_ids = var.vpc.subnet_tier_ids
      security_group_rules = merge(
        {
          ingress_all = {
            type                     = "ingress"
            from_port                = 0
            to_port                  = 0
            protocol                 = "-1"
            description              = "Allow all traffic from ELB"
            source_security_group_id = module.elb.security_group.id
          }
        },
        {
          egress_all = {
            type        = "egress"
            from_port   = 0
            to_port     = 0
            protocol    = "-1"
            cidr_blocks = ["0.0.0.0/0"]
            description = "Allow all traffic"
          }
        }
      )

      create_iam_role     = false
      iam_role_tags       = var.tags
      iam_role_statements = {}

      #---------------------
      # Task definition
      #---------------------
      create_task_exec_iam_role = true
      task_exec_iam_role_tags   = var.tags
      task_exec_iam_statements = merge(
        {
          custom = {
            actions = [
              # // AmazonECSTaskExecutionRolePolicy for fargate 
              # // AmazonEC2ContainerServiceforEC2Role for ec2
              "ec2:DescribeTags",
              "ecs:CreateCluster",
              "ecs:DeregisterContainerInstance",
              "ecs:DiscoverPollEndpoint",
              "ecs:Poll",
              "ecs:RegisterContainerInstance",
              "ecs:StartTelemetrySession",
              "ecs:UpdateContainerInstancesState",
              "ecs:Submit*",
              "ecs:StartTask",
            ]
            effect    = "Allow"
            resources = ["*"],
          },
        },
        try(
          {
            bucket-env = {
              actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
              effect    = "Allow"
              resources = ["arn:${local.partition}:s3:::${var.bucket_env.name}"],
            },
            bucket-env-files = {
              actions   = ["s3:GetObject"]
              effect    = "Allow"
              resources = ["arn:${local.partition}:s3:::${var.bucket_env.name}/${var.bucket_env.file_key}"],
            },
            bucket-encryption = {
              actions   = ["kms:GetPublicKey", "kms:GetKeyPolicy", "kms:DescribeKey"]
              effect    = "Allow"
              resources = ["arn:${local.partition}:kms:${local.region_name}:${local.account_id}:alias/${var.bucket_env.name}"],
            },
          },
          {}
        ),
        try(
          {
            ecr = {
              actions = [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr-public:GetAuthorizationToken",
                "ecr-public:BatchCheckLayerAvailability",
              ]
              effect = "Allow"
              resources = [for container in var.ecs.service.task.containers : "arn:${local.partition}:${
                local.ecr_services[container.docker.registry.ecr.privacy]
                }:${
                container.docker.registry.ecr.privacy == "private" ? coalesce(container.docker.registry.ecr.region_name, local.region_name) : "us-east-1"
                }:${
                coalesce(try(container.docker.registry.ecr.account_id, null), local.account_id)
              }:repository/${container.docker.repository.name}"]
            }
          },
          {}
        ),
      )

      create_tasks_iam_role = true
      task_iam_role_tags    = var.tags
      tasks_iam_role_statements = {
        custom = {
          actions = [
            "ec2:Describe*",
          ]
          effect    = "Allow"
          resources = ["*"],
        },
      }

      # Task definition
      cpu    = var.ecs.service.task.cpu
      memory = var.ecs.service.task.memory

      family                   = var.name
      requires_compatibilities = var.ecs.service.ec2 != null ? ["EC2"] : ["FARGATE"]
      // https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/networking-networkmode.html
      network_mode = var.ecs.service.ec2 != null ? "bridge" : "awsvpc" // "host" for single instance

      placement_constraints = try(var.ecs.service.ec2.chip_type == "inf", false) ? [
        {
          "type" : "memberOf",
          "expression" : "attribute:ecs.os-type == linux"
        },
        {
          "type" : "memberOf",
          "expression" : "attribute:ecs.instance-type == ${var.ecs.service.ec2.instance_types[0]}"
        }
      ] : []

      volume = flatten([
        for container in var.ecs.service.task.containers : [
          for mount_point in container.mount_points :
          {
            name      = mount_point.s3.name
            host_path = null
            docker_volume_configuration = {
              scope         = "shared"
              autoprovision = false
              driver        = "rexray/s3fs:latest"
              driver_opts   = null
            }
          } if mount_point.s3 != null
        ]
      ])

      runtime_platform = var.ecs.service.ec2 != null ? {
        "operatingSystemFamily" = local.os_to_ecs_os_mapping[var.ecs.service.ec2.os],
        "cpuArchitecture"       = local.arch_to_ecs_arch_mapping[var.ecs.service.ec2.architecture],
        } : {
        "operatingSystemFamily" = local.os_to_ecs_os_mapping[var.ecs.service.fargate.os],
        "cpuArchitecture"       = local.arch_to_ecs_arch_mapping[var.ecs.service.fargate.architecture],
      }

      # Task definition container(s)
      # https://github.com/terraform-aws-modules/terraform-aws-ecs/blob/master/modules/container-definition/variables.tf
      container_definitions = {
        for container in var.ecs.service.task.containers : "${var.name}-${container.name}" => {

          # enable_cloudwatch_logging              = true
          # create_cloudwatch_log_group            = true
          # cloudwatch_log_group_retention_in_days = 30
          # cloudwatch_log_group_kms_key_id        = null

          # name = var.name
          environment_files = try([{
            "value" = "arn:${local.partition}:s3:::${var.bucket_env.name}/${var.bucket_env.file_key}",
            "type"  = "s3"
          }], [])
          environment = container.environments,

          # https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_PortMapping.html
          port_mappings = [for target in local.container_targets[container.name] : {
            containerPort = target.port
            hostPort      = var.ecs.service.ec2 != null ? 0 : target.port // "host" network can use target port 
            name          = join("-", ["container", target.protocol, target.port])
            protocol      = target.protocol_version == "grpc" ? "tcp" : target.protocol // TODO: local.layer7_to_layer4_mapping[target.protocol]
            }
          ]
          cpu                = container.cpu
          memory             = container.memory
          memory_reservation = container.memory

          log_configuration = null # other driver than json-file

          resource_requirements = try(var.ecs.service.ec2.chip_type == "gpu", false) ? [{
            "type" : "GPU",
            "value" : "${length(container.device_idxs)}"
          }] : []

          command                  = container.command
          entrypoint               = container.entrypoint
          readonly_root_filesystem = container.readonly_root_filesystem
          user                     = container.user
          mount_points = [
            for mount_point in container.mount_points :
            {
              readOnly      = mount_point.read_only
              containerPath = mount_point.container_path
              sourceVolume  = mount_point.s3.name
            } if mount_point.s3 != null
          ]

          # health_check      = {}
          # volumes_from      = []
          # working_directory = ""

          linuxParameters = try(var.ecs.service.ec2.chip_type == "inf", false) ? {
            "devices" = [for device_idx in container.device_idxs : {
              "containerPath" = "/dev/neuron${device_idx}",
              "hostPath"      = "/dev/neuron${device_idx}",
              "permissions" : ["read", "write"],
              }
            ],
            "capabilities" = {
              "add" = [
                "IPC_LOCK"
              ]
            }
            } : {
            devices      = []
            capabilities = {}
          }

          image = join("/", compact([
            try(
              container.docker.registry.ecr.privacy == "private" ? (
                "${
                  coalesce(try(container.docker.registry.ecr.account_id, null), local.account_id)
                  }.dkr.ecr.${
                  container.docker.registry.ecr.privacy == "private" ? coalesce(container.docker.registry.ecr.region_name, local.region_name) : "us-east-1"
                }.${local.dns_suffix}"
                ) : (
                "public.ecr.aws/${container.docker.registry.ecr.public_alias}"
              ),
              container.docker.registry.name,
              null
            ),
            join(":", compact([container.docker.repository.name, try(container.docker.image.tag, "")]))
          ]))

          essential = true
        }
      }
    }
  }

  tags = var.tags
}
