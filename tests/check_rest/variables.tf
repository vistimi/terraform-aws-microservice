variable "health_checks" {
  type = list(object({
    url                   = string
    header                = optional(any)
    method                = optional(string)
    request_body          = optional(string)
    response_status_codes = list(number)
  }))
}

variable "command" {
  type = object({
    previous = optional(string, "echo nothing to do")
    after    = optional(string, "echo nothing to do")
  })
  default = {
    previous = "echo nothing to do"
    after    = "echo nothing to do"
  }
}
