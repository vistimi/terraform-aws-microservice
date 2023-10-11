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

variable "layer7_to_layer4_mapping" {
  type = map(string)
}

variable "traffics" {
  type = list(any)
}

variable "deployment_type" {
  type     = string
  nullable = false
}

variable "certificate_arn" {
  type    = string
  default = null
}
