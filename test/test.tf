locals {
  traffics = [{
    "listener" = { "protocol" = "http", "port" = 80 },
    "base"     = false,
    "target"   = { "protocol" = "http", "port" = 80, "health_check_path" = "/", protocol_version = "http1" }
    }, {
    "listener" = { "port" = 81, "protocol" = "http" },
    "base"     = false,
    "target"   = { "protocol" = "http", "port" = 80, "health_check_path" = "/", protocol_version = "http1" }
    }, {
    "listener" = { "protocol" = "https", "port" = 443 },
    "base"     = false,
    "target"   = { "protocol" = "http", "port" = 80, "health_check_path" = "/", protocol_version = "http1" }
  }]
}

output "test" {
  value = distinct(flatten([for traffic in local.traffics : {
    port             = traffic.target.port
    protocol         = traffic.target.protocol
    protocol_version = traffic.target.protocol_version
  }]))
}
