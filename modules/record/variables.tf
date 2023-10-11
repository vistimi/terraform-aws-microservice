variable "zone_name" {
  description = "The name of the zone"
  type        = string
}

variable "record" {
  description = "The name of the zone"
  type = object({
    subdomain_name = string
    extensions     = optional(list(string), [])
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
