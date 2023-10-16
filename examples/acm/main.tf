locals {
  name = "microservice-with-acm"
}

module "microservice" {
  source = "vistimi/microservice/aws"

  name = local.name

  traffics = [
    {
      listener = {
        # port is by default 443 with https
        protocol = "https"
      }
      target = {
        port = 8080
      }
    }
  ]

  # needs a route 53 defined
  route53 = {
    zones = [{
      name = "mydomain.com"
    }]
    record = {
      prefixes       = [] # optional
      subdomain_name = local.name
    }
  }

  vpc          = {} # ...
  orchestrator = {} # ...
}
