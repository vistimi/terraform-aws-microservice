variable "health_checks" {
  type = list(object({
    url                   = string
    header                = optional(any)
    method                = optional(string)
    request_body          = optional(string)
    response_status_codes = list(number)
  }))
}
