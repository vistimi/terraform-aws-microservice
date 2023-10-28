module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-ecs"

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            # own private ecr repository
            docker = {
              registry = {
                ecr = {
                  privacy = "private"
                }
              }
              repository = {
                name = "my_private_ecr_repo_name"
              }
              image = {
                tag = "latest"
              }
            }
            # ...
          },
          {
            # own ecr public repository
            docker = {
              registry = {
                ecr = {
                  privacy      = "public"
                  public_alias = "my_public_registry_alias"
                }
              }
              repository = {
                name = "my_public_ecr_repo_name"
              }
              image = {
                tag = "latest"
              }
            }
            # ...
          },
          {
            # other account
            docker = {
              registry = {
                ecr = {
                  privacy     = "private"
                  account_id  = "763104351884"
                  region_name = "us-east-1"
                }
              }
              repository = {
                name = "pytorch-training"
              }
              image = {
                tag = "1.8.1-gpu-py36-cu111-ubuntu18.04-v1.7"
              }
            }
            # ...
          },
          {
            # https://hub.docker.com/r/pytorch/torchserve
            docker = {
              registry = {
                name = "pytorch"
              }
              repository = {
                name = "torchserve"
              }
              image = {
                tag = "latest"
              }
            }
            # ...
          },
          {
            # https://hub.docker.com/_/ubuntu
            docker = {
              repository = {
                name = "ubuntu"
              }
              image = {
                tag = "latest"
              }
            }
            # ...
          }
        ]
      }
      # ...
    }
    # ...
  }

  vpc = {} # ...
}
