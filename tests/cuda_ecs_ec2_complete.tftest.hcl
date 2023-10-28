run "aws" {
  command = apply

  module {
    source = "./tests/aws"
  }
}

run "random_id" {
  command = apply

  variables {
    byte_length = 2
  }

  module {
    source = "./tests/random_id"
  }
}

run "get_env" {
  command = apply

  module {
    source = "./tests/get_env"
  }
}

variables {
  orchestrator = {
    group = {
      name = "g1"
      deployment = {
        min_size     = 1
        max_size     = 1
        desired_size = 1

        containers = [
          {
            name = "c1"
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
            traffics = [
              # add an api or visualization tool to monitor the training
              # tensorboard or else
            ]
            entrypoint = ["/bin/bash", "-c"]
            command = [
              <<EOT
              git clone https://github.com/pytorch/examples.git
              pip install -r examples/mnist_hogwild/requirements.txt
              python3 examples/mnist_hogwild/main.py --epochs 1
              EOT
            ]
            readonly_root_filesystem = false
          }
        ]
      }
      ec2 = {
        instance_types = ["g4dn.xlarge"]
        os             = "linux"
        os_version     = "2"
        capacities = [{
          type = "ON_DEMAND"
        }]
      }
    }
    ecs = {}
  }

}

run "microservice" {
  command = apply

  variables {
    name = "inf-ecs-ec2-com-${run.random_id.id}"

    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = var.orchestrator
    tags = {
      TestID    = run.random_id.id
      AccountID = run.aws.account_id
      UserName  = run.aws.user_name
    }
  }

  module {
    source = "./"
  }
}
