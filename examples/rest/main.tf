module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-rest-http1"

  traffics = [
    {
      listener = {
        # port is by default 80 with http
        protocol         = "http"
        protocol_version = "http1" # by default it is `http1`
      }
      target = {
        port              = 8080
        protocol          = "http"  # if not specified, the protocol will be the same as the listener
        health_check_path = "/ping" # if not specified, the health_check_path will be "/"
        protocol_version  = "http1" # by default it is `http1`
      }
      base = true # only one base that will be the default traffic for the load balancer
    },
    {
      # this will redirect http:81 to http:8080
      listener = {
        port     = 81
        protocol = "http"
      }
    },
  ]

  vpc          = {} # ...
  orchestrator = {} # ...
}

# TODO: this configuration has not been tested yet
module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-rest-http2"

  traffics = [
    {
      listener = {
        # port is by default 80 with http
        protocol         = "http"
        protocol_version = "http2" # by default it is `http1`
      }
      target = {
        port              = 8080
        protocol          = "http"  # if not specified, the protocol will be the same as the listener
        health_check_path = "/ping" # if not specified, the health_check_path will be "/"
        protocol_version  = "http2" # by default it is `http1`
      }
      base = true # only one base that will be the default traffic for the load balancer
    },
    {
      # this will redirect http:81 to http:8080
      listener = {
        port     = 81
        protocol = "http"
      }
    },
  ]

  vpc          = {} # ...
  orchestrator = {} # ...
}
