locals {
  protocols = {
    http    = "HTTP"
    https   = "HTTPS"
    tcp     = "TCP"
    udp     = "UDP"
    tcp_udp = "TCP_UDP"
    ssl     = "SSL"
  }
  protocol_versions = {
    http1 = "HTTP1"
    http2 = "HTTP2"
    grpc  = "GRPC"
  }

  load_balancer_types = {
    http    = "application"
    https   = "application"
    tls     = "network"
    tcp     = "network"
    tcp_udp = "network"
    udp     = "network"
  }

  unique_targets = distinct([for traffic in var.traffics : {
    port              = traffic.target.port
    protocol          = traffic.target.protocol
    protocol_version  = traffic.target.protocol_version
    health_check_path = traffic.target.health_check_path
    status_code       = traffic.target.status_code
  }])

  unique_listeners = distinct([for traffic in var.traffics : {
    protocol         = traffic.listener.protocol
    port             = traffic.listener.port
    protocol_version = traffic.listener.protocol_version
  }])
}

# Cognito for authentication: https://github.com/terraform-aws-modules/terraform-aws-alb/blob/master/examples/complete-alb/main.tf
module "elb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "8.6.0"

  name = var.name

  load_balancer_type = local.load_balancer_types[var.traffics[0].listener.protocol] // map listener base to load balancer

  vpc_id          = var.vpc.id
  subnets         = var.vpc.subnet_tier_ids
  security_groups = local.load_balancer_types[var.traffics[0].listener.protocol] == "application" ? [module.elb_sg.security_group_id] : []

  http_tcp_listeners = [
    for traffic in var.traffics : {
      port               = traffic.listener.port
      protocol           = local.protocols[traffic.listener.protocol]
      target_group_index = [for index, target in local.unique_targets : index if target.port == traffic.target.port][0]
    } if contains(["http", "tcp", "tcp_udp", "udp"], traffic.listener.protocol)
  ]

  https_listeners = [
    for traffic in var.traffics : {
      port               = traffic.listener.port
      protocol           = local.protocols[traffic.listener.protocol]
      certificate_arn    = var.certificate_arn
      target_group_index = [for index, target in local.unique_targets : index if target.port == traffic.target.port][0]
    } if contains(["https", "tls"], traffic.listener.protocol)
  ]

  // forward listener to target
  // HTTP2 can work for grpc and rest
  // https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-protocol-version
  target_groups = [for target in local.unique_targets : {
    name             = join("-", [var.name, target.protocol, target.port])
    backend_protocol = local.protocols[target.protocol]
    backend_port     = target.port
    target_type      = var.deployment_type == "fargate" ? "ip" : "instance" # "ip" for awsvpc network, instance for host or bridge
    health_check = {
      enabled             = true
      interval            = 15 // seconds before new request
      path                = target.health_check_path
      port                = var.deployment_type == "ec2" ? null : target.port // traffic port by default
      healthy_threshold   = 3                                                 // consecutive health check failures before healthy
      unhealthy_threshold = 3                                                 // consecutive health check failures before unhealthy
      timeout             = 5                                                 // seconds for timeout of request
      protocol            = local.protocols[target.protocol]
      matcher = target.status_code != null ? target.status_code : (
        contains(["http", "http2"], target.protocol_version) ? "200-299" : (contains(["grpc"], target.protocol_version) ? "0" : null)
      )
    }
    protocol_version = try(local.protocol_versions[target.protocol_version], null)
    }
  ]

  # Sleep to give time to the ASG not to fail
  load_balancer_create_timeout = "5m"
  load_balancer_update_timeout = "5m"

  tags = var.tags
}

module "elb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.0.0"

  name        = "${var.name}-sg-elb"
  description = "Security group for ALB within VPC"
  vpc_id      = var.vpc.id

  ingress_with_cidr_blocks = [
    for listener in local.unique_listeners : {
      from_port   = listener.port
      to_port     = listener.port
      protocol    = var.layer7_to_layer4_mapping[listener.protocol]
      description = "listener port ${var.layer7_to_layer4_mapping[listener.protocol]} ${listener.port}"
      cidr_blocks = "0.0.0.0/0"
    } if contains(["http", "https"], listener.protocol)
  ]
  egress_rules = ["all-all"]
  # egress_cidr_blocks = module.vpc.subnets_cidr_blocks

  tags = var.tags
}
