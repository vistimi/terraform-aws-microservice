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
          device_idxs = optional(list(number))
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
          traffics = optional(list(object({
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
          })))
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
        chip_type      = string

        asg = optional(object({
          instance_refresh = object({
            strategy = string
            preferences = optional(object({
              checkpoint_delay             = optional(number)
              checkpoint_percentages       = optional(list(number))
              instance_warmup              = optional(number)
              min_healthy_percentage       = optional(number)
              skip_matching                = optional(bool)
              auto_rollback                = optional(bool)
              scale_in_protected_instances = optional(string)
              standby_instances            = optional(string)
            }))
            triggers = optional(list(string))
          })
          }), {
          instance_refresh = {
            strategy = "Rolling"
            preferences = {
              min_healthy_percentage       = 66
              auto_rollback                = true
              scale_in_protected_instances = "Refresh"
              standby_instances            = "Terminate"
            }
            triggers = ["tag"]
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
}
