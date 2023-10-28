variable "health_checks" {
  type = list(object({
    request = string
    adress  = string
    service = string
    method  = string
  }))
}
