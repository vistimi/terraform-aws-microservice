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
}

run "microservice-no-vpc-subnets" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id              = run.get_env.vpc_id
      subnet_tier_ids = []
    }
    orchestrator = var.orchestrator
  }

  module {
    source = "./"
  }

  expect_failures = [var.vpc]
}


run "microservice-two-orcherstrators" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
      }
      ecs = {}
      eks = {
        cluster_version = "1"
      }
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-ec2-and-fargate" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
        ec2 = {
          instance_types = ["t3.medium"]
          os             = "linux"
          os_version     = "2023"
        }
        fargate = {
          os           = "linux"
          architecture = "x86_64"
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-docker-registry-name" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              registry   = {}
              repository = { name = "ubuntu" }
            }
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-docker-registry-ecr-privacy" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              registry   = { ecr = { privacy = "error" } }
              repository = { name = "ubuntu" }
            }
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-docker-registry-ecr-public-no-alias" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              registry   = { ecr = { privacy = "public", public_alias = null } }
              repository = { name = "ubuntu" }
            }
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-traffic-listener-protocol" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              repository = { name = "ubuntu" }
            }
            traffics = [{
              listener = {
                protocol = "error"
              }
              target = {
                port = 80
              }
            }]
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-traffic-listener-protocol-version" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              repository = { name = "ubuntu" }
            }
            traffics = [{
              listener = {
                protocol         = "http"
                protocol_version = "error"
              }
              target = {
                port = 80
              }
            }]
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-traffic-target-protocol" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              repository = { name = "ubuntu" }
            }
            traffics = [{
              listener = {
                protocol = "http"
              }
              target = {
                port     = 80
                protocol = "error"
              }
            }]
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-traffic-target-protocol-version" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = [{
            name = "c1"
            docker = {
              repository = { name = "ubuntu" }
            }
            traffics = [{
              listener = {
                protocol = "http"
              }
              target = {
                port             = 80
                protocol_version = "error"
              }
            }]
          }]
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-fargate-os" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
        fargate = {
          os           = "error"
          architecture = "x86_64"
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-fargate-architecture" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
        fargate = {
          os           = "linux"
          architecture = "error"
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-ec2-instance-types" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
        ec2 = {
          instance_types = ["t3.medium", "t3.medium", "t3.medium"]
          os             = "linux"
          os_version     = "2023"
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-ec2-os" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
        ec2 = {
          instance_types = ["t3.medium"]
          os             = "error"
          os_version     = "2023"
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}

run "microservice-ec2-os-version" {
  command = plan

  variables {
    name = "variables"
    vpc = {
      id       = run.get_env.vpc_id
      tag_tier = "public"
    }
    orchestrator = {
      group = {
        name = "g1"
        deployment = {
          min_size     = 1
          max_size     = 1
          desired_size = 1

          containers = []
        }
        ec2 = {
          instance_types = ["t3.medium"]
          os             = "linux"
          os_version     = "error"
        }
      }
      ecs = {}
    }
  }

  module {
    source = "./"
  }

  expect_failures = [var.orchestrator]
}
