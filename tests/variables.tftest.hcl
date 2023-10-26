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
                  port     = 443
                  protocol = "https"
                }
                target = {
                  port              = 50051
                  protocol_version  = "grpc"
                  status_code       = 0
                  health_check_path = "/helloworld.Greeter/SayHello"
                }
              },
              {
                listener = {
                  port     = 444
                  protocol = "https"
                }
                target = {
                  port              = 50051
                  protocol_version  = "grpc"
                  status_code       = 0
                  health_check_path = "/helloworld.Greeter/SayHello"
                }
              },
            ]
            entrypoint = ["/bin/bash", "-c"]
            command = [
              # listen to 80 by default
              # $${VAR} and %%{VAR} is terraform herodoc
              <<EOT
              apt update -q > /dev/null 2>&1
              apt install apache2 ufw systemctl curl -yq > /dev/null 2>&1
              ufw app list
              echo -e 'Listen 81' >> /etc/apache2/ports.conf; echo print /etc/apache2/ports.conf.....; cat /etc/apache2/ports.conf
              echo -e '<VirtualHost *:81>\nServerAdmin webmaster@localhost\nDocumentRoot /var/www/html\nErrorLog $${APACHE_LOG_DIR}/error.log\nCustomLog $${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>' >> /etc/apache2/sites-enabled/000-default.conf; echo print /etc/apache2/sites-enabled/000-default.conf.....; cat /etc/apache2/sites-enabled/000-default.conf
              systemctl start apache2
              echo test localhost:: $(curl -s -o /dev/null -w '%%{http_code}' localhost)
              echo test localhost:81:: $(curl -s -o /dev/null -w '%%{http_code}' localhost:81)
              sleep infinity
              EOT
            ]
            readonly_root_filesystem = false
          }
        ]
      }
      ec2 = {
        instance_types = ["t3.medium"]
        os             = "linux"
        os_version     = "2023"
        capacities = [{
          type = "ON_DEMAND"
        }]
      }
    }
    ecs = {}
  }


  bucket_env = {
    force_destroy = true
    versioning    = false
    file_key      = "my_branch_name.env"
    file_path     = "override.env"
  }

}

run "env_file" {
  command = apply

  variables {
    content  = <<EOT
    SOME_VAR=some_value
    EOT
    filename = var.bucket_env.file_path
  }

  module {
    source = "./tests/env_file"
  }
}

run "microservice" {
  command = apply

  variables {
    name = "grpc-ecs-fargate-${run.random_id.id}"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = var.orchestrator
    route53 = {
      zones = [{
        name = "${run.get_env.domain_name}.${run.get_env.domain_suffix}"
      }]
      record = {
        prefixes       = ["www"]
        subdomain_name = "grpc-ecs-fargate-${run.random_id.id}"
      }
    }
    bucket_env = var.bucket_env
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

run "check_grpc" {
  command = apply

  variables {
    health_checks = [
      {
        request = "{\"name\": \"World\"}"
        adress  = "${run.microservice.ecs.route53.records["${run.get_env.domain_name}.${run.get_env.domain_suffix}"].name["rest-ecs-fargate-${run.random_id.id} A"]}:443/"
        service = "helloworld.Greeter"
        method  = "SayHello"
      },
      {
        request = "{\"name\": \"World\"}"
        adress  = "www.${run.microservice.ecs.route53.records["${run.get_env.domain_name}.${run.get_env.domain_suffix}"].name["rest-ecs-fargate-${run.random_id.id} A"]}:443/"
        service = "helloworld.Greeter"
        method  = "SayHello"
      },
      {
        request = "{\"name\": \"World\"}"
        adress  = "${run.microservice.ecs.route53.records["${run.get_env.domain_name}.${run.get_env.domain_suffix}"].name["rest-ecs-fargate-${run.random_id.id} A"]}:444/"
        service = "helloworld.Greeter"
        method  = "SayHello"
      },
      {
        request = "{\"name\": \"World\"}"
        adress  = "www.${run.microservice.ecs.route53.records["${run.get_env.domain_name}.${run.get_env.domain_suffix}"].name["rest-ecs-fargate-${run.random_id.id} A"]}:444/"
        service = "helloworld.Greeter"
        method  = "SayHello"
      },
    ]
  }

  module {
    source = "./tests/check_grpc"
  }
}
