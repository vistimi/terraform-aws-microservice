variable "name" {
  description = "The name of the bucket"
  type        = string
}

variable "encryption" {
  description = "Enable server side encryption"
  type = object({
    deletion_window_in_days = optional(number)
  })
  default = null
}

variable "force_destroy" {
  description = "If true, will delete the resources that still contain elements"
  type        = bool
  default     = true
}

variable "versioning" {
  description = "Enable versioning"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Custom tags to set on the Instances in the ASG"
  type        = map(string)
  default     = {}
}
