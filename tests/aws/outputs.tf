output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "account_arn" {
  value = data.aws_caller_identity.current.arn
}

output "dns_suffix" {
  value = data.aws_partition.current.dns_suffix // amazonaws.com
}

output "partition" {
  value = data.aws_partition.current.partition // aws
}

output "region_name" {
  value = data.aws_region.current.name
}

output "user_id" {
  value = data.aws_caller_identity.current.user_id
}

output "user_name" {
  value = regex("^arn:aws:iam::(?P<account_id>\\d+):user/(?P<user_name>\\w+)$", data.aws_caller_identity.current.arn).user_name
}
