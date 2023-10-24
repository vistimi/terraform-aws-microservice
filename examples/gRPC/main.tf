module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-grpc"

  route53 = {
    # ...
  }

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
            traffics = [
              {
                listener = {
                  # port is by default 443 with https
                  protocol = "https"
                }
                target = {
                  port              = 50051
                  protocol_version  = "grpc"
                  health_check_path = "/helloworld.Greeter/SayHello"
                  status_code       = "0"
                }
              },
              {
                # this will redirect https:444 to grpc:50051
                listener = {
                  port     = 444
                  protocol = "https"
                }
                target = {
                  port              = 50051
                  protocol_version  = "grpc"
                  health_check_path = "/helloworld.Greeter/SayHello"
                  status_code       = "0"
                }
              }
            ]
            # ...
          }
        ]
        # ...
      }
      # ...
    }
    # ...
  }

  vpc = {} # ...
}
