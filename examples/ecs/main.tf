module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-ecs"

  orchestrator = {
    group = {} # ...
    ecs   = {} # there is no overriding the default ecs config yet
  }

  vpc      = {} # ...
  traffics = [] # ...
}
