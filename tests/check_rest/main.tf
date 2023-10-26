data "http" "health_checks" {
  for_each = { for health_check in var.health_checks : health_check.url => health_check }

  url = each.key

  lifecycle {
    postcondition {
      condition     = contains(each.value.response_status_codes, self.status_code)
      error_message = "${each.key} returned an unhealthy status code: ${jsonencode(self)}, expected: ${jeonencode(each.value.response_status_codes)}"
    }
  }
}
