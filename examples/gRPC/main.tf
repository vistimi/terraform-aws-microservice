locals {
  name             = "microservice-with-grpc"
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
        port              = 50051
        protocol_version  = "grpc"
        health_check_path = "/helloworld.Greeter/SayHello"
        status_code       = "0"
      }
    }
  ]

  vpc          = {} # ...
  orchestrator = {} # ...
}
