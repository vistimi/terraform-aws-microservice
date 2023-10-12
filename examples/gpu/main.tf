module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-gpu-one-chip-one-container"


  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            name = "unique"
            # ...
          }
          # ...
        ]
        # ...
      }
      ec2 = {
        instance_types = ["g4dn.xlarge"]
        os             = "linux"
        os_version     = "2"
        # ...
      }
    }
    ecs = {}
  }

  vpc      = {} # ...
  traffics = [] # ...
}

# TODO: this configuration has not been tested yet
module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-gpu-four-chips-two-containers"

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            name        = "first-two-gpus"
            cpu         = 24576
            memory      = 98304 - 500 # minus the approximate size taken by the orchestrator
            device_idxs = [0, 1]
            # ...
          },
          {
            name        = "second-two-gpus"
            cpu         = 24576
            memory      = 98304 - 500 # minus the approximate size taken by the orchestrator
            device_idxs = [2, 3]
            # ...
          }
        ]
        # ...
      }
      ec2 = {
        instance_types = ["g4dn.12xlarge"]
        os             = "linux"
        os_version     = "2"
        # ...
      }
    }
    ecs = {}
  }

  vpc      = {} # ...
  traffics = [] # ...
}
