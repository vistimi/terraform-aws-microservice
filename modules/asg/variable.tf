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

variable "port_mapping" {
  type     = string
  nullable = false

  validation {
    condition     = contains(["dynamic", "host"], var.port_mapping)
    error_message = "port mapping must be in [dynamic, host], got ${var.port_mapping}"
  }
}

variable "image_id" {
  type     = string
  nullable = false
}

variable "user_data_base64" {
  type     = string
  nullable = false
}

variable "capacity_provider" {
  type = object({
    weight = number
  })
  nullable = false
}
variable "capacity_weight_total" {
  type     = number
  nullable = false
}

variable "use_spot" {
  type    = bool
  default = false
}

variable "instance_type" {
  type = string
}

variable "processor_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "instance_refresh" {
  type = any
}

variable "target_group_arns" {
  type = list(string)
}

variable "source_security_group_id" {
  type = string
}

variable "min_count" {
  type     = number
  nullable = false
}

variable "max_count" {
  type     = number
  nullable = false
}

variable "desired_count" {
  type     = number
  nullable = false
}

variable "layer7_to_layer4_mapping" {
  type = map(string)
}

variable "traffics" {
  type = list(any)
}
