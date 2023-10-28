module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-inferentia-one-chip-one-container"


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
        instance_types = ["inf1.xlarge"]
        os             = "linux"
        os_version     = "2"
        # ...
      }
    }
    ecs = {}
  }

  vpc = {} # ...
}

# TODO: this configuration has not been tested yet
module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-inferentia-four-chips-two-containers"

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            name        = "first-two-chips"
            cpu         = 12288
            memory      = 24576 - 500 # minus the approximate size taken by the orchestrator
            device_idxs = [0, 1]
            # ...
          },
          {
            name        = "second-two-chips"
            cpu         = 12288
            memory      = 24576 - 500 # minus the approximate size taken by the orchestrator
            device_idxs = [2, 3]
            # ...
          }
        ]
        # ...
      }
      ec2 = {
        instance_types = ["inf1.6xlarge"]
        os             = "linux"
        os_version     = "2"
        # ...
      }
    }
    ecs = {}
  }

  vpc = {} # ...
}
