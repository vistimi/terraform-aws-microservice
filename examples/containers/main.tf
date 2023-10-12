module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-containers"

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            name               = "base"
            base               = true
            cpu                = 2048
            memory             = 2048
            memory_reservation = 100 # optional: will remove memory_reservation from container memory to leave some overhead
            # ...
          },
          {
            name   = "internal"
            cpu    = 1024
            memory = 1024
            # ...
          },
        ]
        # ...
      }
      # ...
    }
    # ...
  }

  vpc      = {} # ...
  traffics = [] # ...
}
