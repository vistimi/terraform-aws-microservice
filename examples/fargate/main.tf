module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-fargate"

  orchestrator = {
    group = {
      cpu    = 512
      memory = 1024

      deployment = {
        cpu    = 512
        memory = 1024
        # ...
      }
      fargate = {
        os           = "linux"
        architecture = "x86_64"
        capacities = [
          # if no capacity provider is specified, `ON_DEMAND` will be used
          {
            type   = "ON_DEMAND"
            base   = true
            weight = 60
          },
          {
            type   = "SPOT"
            weight = 30
          }
        ]
      }
      # ...
    }
    # ...
  }

  vpc = {} # ...
}
