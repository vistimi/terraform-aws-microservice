output "name" {
  value = module.records.route53_record_name
}

output "fqdn" {
  value = module.records.route53_record_fqdn
}
