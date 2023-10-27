variable "zone_name" {
  description = "The name of the hosted zone"
  type        = string
}

variable "record" {
  description = "The record configuration"
  type = object({
    subdomain_name = string
    prefixes     = optional(list(string), [])
    type           = string
    alias = optional(object({
      name    = string
      zone_id = string
    }))
    ttl            = optional(number)
    records        = optional(list(string))
    set_identifier = optional(string)
  })
}
