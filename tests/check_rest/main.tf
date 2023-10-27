# resource "null_resource" "wait" {
#   provisioner "local-exec" {
#     command = " sleep 1m"
#   }
# }

resource "time_sleep" "wait" {
  create_duration = "90s"
}

data "http" "health_checks" {
  for_each = { for health_check in var.health_checks : health_check.url => health_check }

  url             = each.key
  request_headers = each.value.header
  method          = each.value.method
  request_body    = each.value.request_body

  lifecycle {
    postcondition {
      condition     = contains(each.value.response_status_codes, self.status_code)
      error_message = "${each.key} returned an unhealthy status code: ${jsonencode(self)}, expected: ${jsonencode(each.value.response_status_codes)}"
    }
  }

  depends_on = [time_sleep.wait]
}
