data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  account_arn = data.aws_caller_identity.current.arn
  dns_suffix  = data.aws_partition.current.dns_suffix // amazonaws.com
  partition   = data.aws_partition.current.partition  // aws
  region_name = data.aws_region.current.name

  # icmp, icmpv6, tcp, udp, or all use the protocol number
  # https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
  layer7_to_layer4_mapping = {
    http    = "tcp"
    https   = "tcp"
    tcp     = "tcp"
    udp     = "udp"
    tcp_udp = "tcp"
    ssl     = "tcp"
  }

  ecr_services = {
    private = "ecr"
    public  = "ecr-public"
  }

  os_to_ecs_os_mapping = {
    linux = "LINUX"
  }
  arch_to_ecs_arch_mapping = {
    x86_64 = "X86_64"
    arm64  = "ARM64"
  }

  traffics = flatten([for container in var.ecs.service.task.containers : container.traffics])

  unique_targets = distinct(flatten([for container in var.ecs.service.task.containers : [for traffic in container.traffics : {
    port              = traffic.target.port
    protocol          = traffic.target.protocol
    protocol_version  = traffic.target.protocol_version
    health_check_path = traffic.target.health_check_path
    status_code       = traffic.target.status_code
  }]]))

  unique_listeners = distinct(flatten([for container in var.ecs.service.task.containers : [for traffic in container.traffics : {
    protocol         = traffic.listener.protocol
    port             = traffic.listener.port
    protocol_version = traffic.listener.protocol_version
  }]]))

  asgs = {
    for obj in flatten([for instance_type in try(var.ecs.service.ec2.instance_types, []) : [for capacity in try(var.ecs.service.ec2.capacities, []) : {
      instance_regex = regex("^(?P<prefix>\\w+)\\.(?P<size_number>\\d*x*)(?P<size_name>\\w+)$", instance_type)
      instance_type  = instance_type
      capacity       = capacity
      }
    ]]) : lower(join("-", compact([var.name, substr(obj.capacity.type, 0, 2), "${obj.instance_regex.prefix}-${obj.instance_regex.size_number}${substr(obj.instance_regex.size_name, 0, 1)}"]))) => { instance_type = obj.instance_type, capacity = obj.capacity }
  }
}
