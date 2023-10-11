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
    id   = string
    tier = string
  })
}

variable "route53" {
  type = object({
    zones = list(object({
      name = string
    }))
    record = object({
      prefixes       = optional(list(string))
      subdomain_name = string
    })
  })
  default = null
}

variable "bucket_env" {
  type = object({
    name          = string
    file_key      = string
  })
  default = null
}

variable "traffics" {
  type = list(object({
    listener = object({
      protocol         = string
      port             = optional(number)
      protocol_version = optional(string)
    })
    target = object({
      protocol          = string
      port              = number
      protocol_version  = optional(string)
      health_check_path = optional(string)
      status_code       = optional(string)
    })
    base = optional(bool)
  }))
}

variable "eks" {
  type = object({
    create          = optional(bool, true)
    cluster_version = string
    group = object({
      name = string
      deployment = object({
        min_size        = number
        max_size        = number
        desired_size    = number
        maximum_percent = optional(number)

        container = object({
          name = string
        })
      })
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string
        architecture   = string
        processor_type = string

        capacities = optional(list(object({
          type = optional(string, "ON_DEMAND")
        })))
      }))
      fargate = optional(object({}))
    })
  })
}
