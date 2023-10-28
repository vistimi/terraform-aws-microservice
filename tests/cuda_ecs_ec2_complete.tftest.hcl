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
              {
                listener = {
                  protocol = "http"
                }
                target = {
                  port              = 3000
                  health_check_path = "/"
                }
              },
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

run "check_rest" {
  command = apply

  variables {
    health_checks = [
      {
        url = "http://${run.microservice.ecs.elb.lb.dns_name}:8080/ping"
        header = {
          Accept = "application/json"
        }
        method                = "GET"
        response_status_codes = [200]
      },
      {
        url = "http://${run.microservice.ecs.elb.lb.dns_name}:8081/models"
        header = {
          Accept = "application/json"
        }
        method                = "GET"
        response_status_codes = [200]
      },
      {
        url = "http://${run.microservice.ecs.elb.lb.dns_name}:8082/metrics"
        header = {
          Accept = "application/json"
        }
        method                = "GET"
        response_status_codes = [200]
      },
    ]
    command = {
      after = "curl -O https://s3.amazonaws.com/model-server/inputs/kitten.jpg; curl -v -X POST http://${run.microservice.ecs.elb.lb.dns_name}:8080/predictions/densenet161 -T kitten.jpg; rm kitten.jpg"
    }
  }

  module {
    source = "./tests/check_rest"
  }
}
