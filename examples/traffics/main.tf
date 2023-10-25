module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-container-traffics"

  orchestrator = {
    group = {
      deployment = {
        containers = [
          {
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
              },
              {
                # this will redirect https:444 to http:80
                listener = {
                  port     = 444
                  protocol = "https"
                }
                target = {
                  port              = 80
                  protocol          = "http" # if not specified, the protocol will be the same as the listener
                  health_check_path = "/"    # if not specified, the health_check_path will be "/"
                }
              },
              {
                # this will redirect http:81 to http:81
                listener = {
                  port     = 81
                  protocol = "http"
                }
                target = {
                  port              = 81
                  protocol          = "http" # if not specified, the protocol will be the same as the listener
                  health_check_path = "/"    # if not specified, the health_check_path will be "/"
                }
              },
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

  vpc      = {} # ...
  traffics = [] # ...
}
