# AWS microservice terraform module

Terraform module which creates a microservice that works for all Fargate/EC2 instances. The applications can range from deploying general purpose applications, machine learning training. machine learning inference, high performance computing and more.

There are already some terraform microservices available, however they offer low variety in configurations and usually only supports Fargate. Here you have access to all EC2 instances with easy configuration.

## Usage

```hcl
module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-complete"

  bucket_env = {
    force_destroy = false
    versioning    = true
    file_key      = "file_local_name.env"
    file_path     = "file_in_bucket_name.env"
  }

  vpc = {
    id               = "my_vpc_id"
    subnet_tier_ids  = ["id_subnet_tier_1", "id_subnet_tier_2"]
    subnet_intra_ids = ["id_subnet_intra_1", "id_subnet_intra_2"]
  }

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

            traffics = [
              {
                # this will redirect http:80 to http:80
                listener = {
                  # port is by default 80 with http
                  protocol = "http"
                }
                target = {
                  port              = 80
                  protocol          = "http" # if not specified, the protocol will be the same as the listener
                  health_check_path = "/"    # if not specified, the health_check_path will be "/"
                }
              }
            ]

            entrypoint = [
              "/bin/bash",
              "-c",
            ]
            command = [
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
        key_name       = "name_of_key_to_ssh_with"
        instance_types = ["t2.micro"]
        os             = "linux"
        os_version     = "2023"
        capacities = [
          # no need to have multiple specified. If only one, only `type` is needed.
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
    ecs = {
      # override default ecs behaviour
    }
  }

  tags = {}
}
```

## Data platforms or frameworks
:ok_woman: If you want to unify your infrastructure with terraform, use this module. Terraform covers a wide range of cloud providers, hence reducing dependability over one provider/platform.
:ok_man:If you want to use other serving systems such as torchserve or TensorFlow Serving, then use this module.

Data platforms are a great way to simply and efficiently manage your AI lifecycle from training to deployment. However they are quite pricy and only work for data application. Some frameworks like ray.io cluster or mlflow.org will offer easily lifecycle management from local machine to complex cloud deployment for ML projects.

:no_good:If your application is only oriented towards ML, check out alternative tools that might be better for your application.

## Specificities

- heterogeneous clusters, consisting of different instance types
- Parallelizing data processing with autoscaling

The microservice has the following specifications:

- Load balancer
    - HTTP(S)
    - Rest/gRPC
- Auto scaling
- DNS with Route53
- Environement file
- Cloudwatch logs
- Container orchestrators
    - ECS
      - [x] Fargate
      - EC2
          - [x] General Purpose
          - [x] Compute Optimized
          - [x] Memory Optimized
          - [x] Accelerated Computing (GPU, Inferentia, Trainium)
          - [ ] Accelerated Computing (Gaudi) not supported
          - [ ] Storage Optimized: supported/not tested
          - [ ] HPC Optimized: supported/not tested
    - EKS
        - [ ] Fargate
        - [ ] EC2

## Usage

```hcl
module "microservice" {
  source  = "vistimi/microservice/aws"
  version = "0.0.12"

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
              <<EOT
              # run some commands
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
```

## Architecture

![Architecture](https://github.com/vistimi/terraform-aws-microservice/blob/trunk/images/architecture.png?raw=true)

## Examples

Go check the [examples](https://github.com/vistimi/terraform-aws-microservice/tree/trunk/examples)
Go check the [tests](https://github.com/vistimi/terraform-aws-microservice/tree/trunk/tests/microservice)

## ECS vs EKS equivalent

|         ECS          |    EKS     |
| :------------------: | :--------: |
|       cluster        |  cluster   |
|       service        | node-group |
|         task         |    node    |
|   task-definition    | deployment |
| container-definition |    pod     |

## Errors

##### insufficient memory
```
The closest matching container-instance `<id>` has insufficient memory available. For more information, see the Troubleshooting section of the Amazon ECS Developer Guide
```

It means that the memory given to the container or the service or both is superior to what is allowed. ECS requires a certain amount of memory to run and is different for each instance. Currently there is only 90% of the memory used for the containers, leaving enough overhead space to not encounter that problem. To override that from happening you can override the memory and cpu allocation by specifying it in the containers.

##### insufficient instances
```
Scaling activity `<id>`: Failed: We currently do not have sufficient `<instance_type>` capacity in the Availability Zone you requested (us-east-1c). Our system will be working on provisioning additional capacity. You can currently get `<instance_type>` capacity by not specifying an Availability Zone in your request or choosing us-east-1a, us-east-1b, us-east-1d, us-east-1f. Launching EC2 instance failed
```

It means that not available instances in the available zones. Unfortunately AWS does not have enough capacity in some regions. A possible solution would be to retry deploying the microservice until it is successful.

## Makefile

If the env variables are not defined:
```sh
make aws-auth AWS_ACCESS_KEY=*** AWS_SECRET_KEY=*** AWS_REGION_NAME=***
make prepare AWS_ACCOUNT_ID=*** AWS_REGION_NAME=***
```

otherwise:
```sh
make aws-auth
make prepare
```

## License

See [LICENSE](https://github.com/vistimi/terraform-aws-microservice/tree/trunk/LICENSE) for full details.
