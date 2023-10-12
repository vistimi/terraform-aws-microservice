module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-acm"

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

  vpc          = {} # ...
  orchestrator = {} # ...
}
