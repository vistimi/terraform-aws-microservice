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
              repository = {
                name = "ubuntu"
              }
              image = {
                tag = "latest"
              }
            }
            traffics = [
              {
                listener = {
                  port     = 80
                  protocol = "http"
                }
                target = {
                  port = 80
                }
              }
            ]
            entrypoint = ["/bin/bash", "-c"]
            command = [
              # listen to 80 by default
              # $${VAR} and %%{VAR} is terraform herodoc
              <<EOT
              apt update -q > /dev/null 2>&1
              apt install apache2 ufw systemctl curl -yq > /dev/null 2>&1
              ufw app list
              systemctl start apache2
              echo test localhost:: $(curl -s -o /dev/null -w '%%{http_code}' localhost)
              sleep infinity
              EOT
            ]
            readonly_root_filesystem = false
          }
        ]
      }
      ec2 = {
        instance_types = ["m6i.large"]
        os             = "linux"
        os_version     = "2023"
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
    name = "rest-ecs-fargate-${run.random_id.id}"
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
        url = "http://${run.microservice.ecs.elb.lb.dns_name}:80/"
        header = {
          Accept = "application/json"
        }
        method                = "GET"
        response_status_codes = [200]
      }
    ]
  }

  module {
    source = "./tests/check_rest"
  }
}
