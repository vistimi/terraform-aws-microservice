module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-complete"

  bucket_env = {
    force_destroy = true
    versioning    = false
    file_key      = "file_local_name.env"
    file_path     = "file_in_bucket_name.env"
  }

  vpc = {
    id               = "my_vpc_id"
    subnet_tier_ids  = ["id_subnet_tier_1", "id_subnet_tier_2"]
    subnet_intra_ids = ["id_subnet_intra_1", "id_subnet_intra_2"]
  }

  traffics = [
    {
      listener = {
        # port is by default 443 with https
        protocol = "http"
      }
      target = {
        port              = 8080
        protocol          = "http"  # if not specified, the protocol will be the same as the listener
        health_check_path = "/ping" # if not specified, the health_check_path will be "/"
      }
    },
    {
      # this will redirect https:444 to http:8080
      listener = {
        port     = 444
        protocol = "https"
      }
    },
    {
      # this will redirect http:80 to http:8080
      listener = {
        # port is by default 80 with http
        protocol = "http"
      }
    },
    {
      # this will redirect http:81 to http:8080
      listener = {
        port     = 81
        protocol = "http"
      }
    },
  ]

  orchestrator = {
    group = {
      name = "first"
      deployment = {
        min_size     = 1
        max_size     = 2
        desired_size = 1

        containers = [
          {
            name = "first"
            docker = {
              repository = {
                name = "ubuntu"
              }
              image = {
                tag = "latest"
              }
            }

            entrypoint = [
              "/bin/bash",
              "-c",
            ]
            command = [
              "apt update -q; apt install apache2 ufw systemctl curl -yq; ufw app list; systemctl start apache2; curl localhost; sleep infinity",
            ]
            readonly_root_filesystem = false
          }
        ]
      }

      ec2 = {
        key_name       = "name_of_key_to_ssh_with"
        instance_types = ["t2.micro"]
        os             = "linux"
        os_version     = "2023"
        capacities = [
          # no need to have multiple specified, if only one only `type` is needed
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
    }
    ecs = {}
  }

  tags = {}
}
