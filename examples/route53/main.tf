locals {
  name             = "microservice-with-dns"
  hosted_zone_name = "mydomain.com"
}

module "microservice" {
  source = "vistimi/microservice/aws"

  name = local.name

  # will create an available DNS record like www.microservice-with-dns.mydomain.com and whatever.microservice-with-dns.mydomain.com
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
