locals {
  fargate_capacity_provider_keys = {
    ON_DEMAND = "FARGATE"
    SPOT      = "FARGATE_SPOT"
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "5.2.0"

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
    for capacity in var.ecs.service.ec2.capacities :
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
      subnets          = var.ecs.service.ec2 != null ? null : local.subnets
      assign_public_ip = var.ecs.service.ec2 != null ? null : true // if private subnets, use NAT

      load_balancer = {
        # TODO: this-service
        service = {
          target_group_arn = element(module.elb.target_group.arns, 0) // one LB per target group
          container_name   = length(var.ecs.service.task.containers) == 1 ? "${var.name}-${var.ecs.service.task.containers[0].name}" : [for container in var.ecs.service.task.containers : "${var.name}-${container.name}" if container.base == true][0]
          container_port   = element([for traffic in local.traffics : traffic.target.port if traffic.base == true || length(local.traffics) == 1], 0)
        }
      }

      # security group
      subnet_ids = local.subnets
      security_group_rules = merge(
        {
          for target in distinct([for traffic in local.traffics : {
            port     = traffic.target.port
            protocol = traffic.target.protocol
            }]) : join("-", ["elb", "ingress", target.protocol, target.port]) => {
            type                     = "ingress"
            from_port                = target.port
            to_port                  = target.port
            protocol                 = local.layer7_to_layer4_mapping[target.protocol]
            description              = "Service ${target.protocol} port ${target.port}"
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
      })

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

      placement_constraints = try(var.ecs.service.ec2.architecture == "inf", false) ? [
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
          port_mappings = [for target in distinct([for traffic in local.traffics : {
            port             = traffic.target.port
            protocol         = traffic.target.protocol
            protocol_version = traffic.target.protocol_version
            }]) : {
            containerPort = target.port
            hostPort      = var.ecs.service.ec2 != null ? 0 : target.port // "host" network can use target port 
            name          = join("-", ["container", target.protocol, target.port])
            protocol      = target.protocol_version == "grpc" ? "tcp" : target.protocol // TODO: local.layer7_to_layer4_mapping[target.protocol]
            }
          ]
          cpu                = container.cpu
          memory             = container.memory - container.memory_reservation
          memory_reservation = container.memory - container.memory_reservation

          log_configuration = null # other driver than json-file

          resource_requirements = try(var.ecs.service.ec2.architecture == "gpu", false) ? [{
            "type" : "GPU",
            "value" : "${length(container.device_idx)}"
          }] : []

          # command = flatten(concat([
          #   for mount_point in container.mount_points :
          #   [
          #     "yum install -y gcc libstdc+-devel gcc-c+ fuse fuse-devel curl-devel libxml2-devel mailcap automake openssl-devel git gcc-c++",
          #     "git clone https://github.com/s3fs-fuse/s3fs-fuse",
          #     "cd s3fs-fuse/",
          #     "./autogen.sh",
          #     "./configure --prefix=/usr --with-openssl",
          #     "make",
          #     "make install",
          #     "docker plugin install rexray/s3fs:latest S3FS_REGION=${local.region_name} S3FS_OPTIONS=\"allow_other,iam_role=auto,umask=000\" LIBSTORAGE_INT,EGRATION_VOLUME_OPERATIONS_MOUNT_ROOTPATH=/ --grant-all-permissions",
          #     "yum update -y ecs-init",
          #     "service docker restart && start ecs",
          #   ] if mount_point.s3 != null
          #   ],
          #   container.command
          # ))
          # entrypoint = flatten(concat([
          #   for mount_point in container.mount_points :
          #   [
          #     "/bin/bash",
          #     "-c",
          #   ] if mount_point.s3 != null
          #   ],
          #   container.entrypoint
          # ))
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

          linuxParameters = var.ecs.service.ec2.architecture == "inf" ? {
            "devices" = [for device_idx in container.devices_idx : {
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

          # fargate AMI
          runtime_platform = var.ecs.service.ec2 != null ? null : {
            "operatingSystemFamily" = local.fargate_os[var.ecs.service.fargate.os],
            "cpuArchitecture"       = local.fargate_architecture[var.ecs.service.fargate.architecture],
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
