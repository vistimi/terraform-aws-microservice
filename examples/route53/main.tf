locals {
  name             = "microservice-with-dns"
  hosted_zone_name = "mydomain.com"
}

module "microservice" {
  source = "vistimi/microservice/aws"

  name = local.name

  # will create the following DNS records: 
  # - microservice-with-dns.mydomain.com
  # - www.microservice-with-dns.mydomain.com
  # - whatever.microservice-with-dns.mydomain.com
  route53 = {
    zones = [{
      name = local.hosted_zone_name
    }]
    record = {
      prefixes       = ["www", "whatever"] # optional
      subdomain_name = local.name
    }
  }

  vpc          = {} # ...
  traffics     = [] # ...
  orchestrator = {} # ...
}
