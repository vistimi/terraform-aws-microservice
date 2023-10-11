locals {
  name             = "microservice-with-acm"
}

module "microservice" {
  source = "vistimi/microservice/aws"

  name = local.name

  traffics = [
    {
      listener = {
        # port is by default 443 with https
        protocol = "https"
        base     = true # only one base that will be the default traffic for the load balancer
      }
      target = {
        port              = 3000
        protocol          = "http" # if not specified, the protocol will be the same as the listener
        health_check_path = "/"
      }
    },
    {
      listener = {
        port     = 444
        protocol = "https"
      }
    },
    {
      listener = {
        # port is by default 80 with http
        protocol = "http"
      }
    },
    {
      listener = {
        port     = 81
        protocol = "http"
      }
    },
    # ...
  ]

  vpc          = {} # ...
  orchestrator = {} # ...
}
