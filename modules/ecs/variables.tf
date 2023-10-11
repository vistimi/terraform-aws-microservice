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
  nullable = false
}

variable "bucket_env" {
  type = object({
    name     = string
    file_key = string
  })
}

variable "ecs" {
  type = object({
    service = object({
      name = string
      task = object({
        min_size        = number
        max_size        = number
        desired_size    = number
        maximum_percent = optional(number)
        cpu             = number
        memory          = number

        containers = list(object({
          name        = string
          base        = optional(bool)
          cpu         = number
          memory      = number
          memory_reservation = number
          devices_idx = optional(list(number))
          environments = optional(list(object({
            name  = string
            value = string
          })), [])
          docker = object({
            registry = optional(object({
              name = optional(string)
              ecr = optional(object({
                privacy      = string
                public_alias = optional(string)
                account_id   = optional(string)
                region_name  = optional(string)
              }))
            }))
            repository = object({
              name = string
            })
            image = optional(object({
              tag = string
            }))
          })
          command                  = optional(list(string), [])
          entrypoint               = optional(list(string), [])
          readonly_root_filesystem = optional(bool)
          user                     = optional(string)
          mount_points = optional(list(object({
            s3 = optional(object({
              name = string
            }))
            container_path = string
            read_only      = optional(bool)
          })), [])
        }))
      })
      ec2 = optional(object({
        key_name       = optional(string)
        instance_types = list(string)
        os             = string
        os_version     = string
        architecture   = string
        processor_type = string

        asg = optional(object({
          instance_refresh = object({
            strategy = string
            preferences = optional(object({
              checkpoint_delay       = optional(number)
              checkpoint_percentages = optional(list(number))
              instance_warmup        = optional(number)
              min_healthy_percentage = optional(number)
              skip_matching          = optional(bool)
              auto_rollback          = optional(bool)
            }))
            triggers = optional(list(string))
          })
          }), {
          instance_refresh = {
            strategy = "Rolling"
            preferences = {
              min_healthy_percentage = 66
            }
          }
        })
        capacities = optional(list(object({
          type                        = optional(string, "ON_DEMAND")
          base                        = optional(number)
          weight                      = optional(number, 1)
          target_capacity_cpu_percent = optional(number, 66)
          maximum_scaling_step_size   = optional(number)
          minimum_scaling_step_size   = optional(number)
        })))
      }))
      fargate = optional(object({
        os           = string
        architecture = string

        capacities = optional(list(object({
          type                        = optional(string, "ON_DEMAND")
          base                        = optional(number)
          weight                      = optional(number, 1)
          target_capacity_cpu_percent = optional(number, 66)
        })))
      }))
    })
  })

  validation {
    condition     = length(var.ecs.service.ec2.instance_types) == 1
    error_message = "ECS configuration only supports one instance type yet"
  }
}
