variable "name" {
  description = "The common part of the name used for all resources"
  type        = string
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}

variable "vpc" {
  type = object({
    id              = string
    subnet_tier_ids = list(string)
  })
}

variable "layer7_to_layer4_mapping" {
  type = map(string)
}

variable "traffics" {
  type = list(object({
    listener = object({
      protocol         = string
      port             = number
      protocol_version = string
    })
    target = object({
      protocol          = string
      port              = number
      protocol_version  = string
      health_check_path = string
      status_code       = optional(string)
    })
  }))
  nullable = false
}

resource "null_resource" "traffics" {
  lifecycle {
    precondition {
      condition     = length(distinct([for traffic in var.traffics : local.load_balancer_types[traffic.listener.protocol]])) == 1
      error_message = "listeners must either use http/https or tls/tcp/tcp_udp/udp, not both/none: ${jsonencode(distinct([for traffic in var.traffics : local.load_balancer_types[traffic.listener.protocol]]))}"
    }
  }
}

variable "deployment_type" {
  type     = string
  nullable = false
}

variable "certificate_arn" {
  type    = string
  default = null
}
