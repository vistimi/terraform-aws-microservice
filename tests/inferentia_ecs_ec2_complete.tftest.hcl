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
                name = "pytorch"
              }
              repository = {
                name = "torchserve"
              }
              image = {
                tag = "latest"
              }
            }
            traffics = [
              {
                listener = {
                  port     = 8080
                  protocol = "http"
                }
                target = {
                  port              = 8080
                  health_check_path = "/ping"
                }
              },
              {
                listener = {
                  port     = 8081
                  protocol = "http"
                }
                target = {
                  port              = 8081
                  health_check_path = "/models"
                }
              },
              {
                listener = {
                  port     = 8082
                  protocol = "http"
                }
                target = {
                  port              = 8082
                  health_check_path = "/metrics"
                }
              },
            ]
            entrypoint = ["/bin/bash", "-c"]
            command = [
              // it needs the libraries and drivers for neuron to use the inferentia chips
              // https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/arch/neuron-features/neuroncore-pipeline.html
              // https://awsdocs-neuron.readthedocs-hosted.com/en/latest/src/examples/pytorch/pipeline_tutorial/neuroncore_pipeline_pytorch.html
              <<EOT
              apt update > /dev/null 2>&1
              apt install git wget curl -y > /dev/null 2>&1
              git clone https://github.com/pytorch/serve.git; cd serve; ls examples/image_classifier/densenet_161/
              wget https://download.pytorch.org/models/densenet161-8d451a50.pth; torch-model-archiver --model-name densenet161 --version 1.0 --model-file examples/image_classifier/densenet_161/model.py --serialized-file densenet161-8d451a50.pth --handler image_classifier --extra-files examples/image_classifier/index_to_name.json
              mkdir -p model_store; mv densenet161.mar model_store/
              echo -e 'load_models=ALL\ninference_address=http://0.0.0.0:8080\nmanagement_address=http://0.0.0.0:8081\nmetrics_address=http://0.0.0.0:8082\nmodel_store=model_store' >> config.properties
              torchserve --start --ncs --ts-config config.properties
              sleep infinity
              EOT
            ]
            readonly_root_filesystem = false
            user                     = "root"
          }
        ]
      }
      ec2 = {
        instance_types = ["inf1.xlarge"]
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
