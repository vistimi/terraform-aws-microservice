module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-ec2-2023"

  orchestrator = {
    group = {
      ec2 = {
        key_name       = "name_of_key_to_ssh_with"
        instance_types = ["t2.micro"]
        os             = "linux"
        os_version     = "2023"
        capacities = [
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

  vpc      = {} # ...
  traffics = [] # ...
}

module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-ec2-2"

  orchestrator = {
    group = {
      ec2 = {
        os         = "linux"
        os_version = "2"
        # ...
      }
      # ...
    }
    # ...
  }

  vpc      = {} # ...
  traffics = [] # ...
}
