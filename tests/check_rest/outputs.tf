output "health_checks" {
  value = data.http.health_checks
}

output "command_previous" {
  value = null_resource.command_previous
}

output "command_after" {
  value = null_resource.command_after
}
