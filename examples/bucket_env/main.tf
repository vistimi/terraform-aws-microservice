module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-with-env"

  bucket_env = {
    force_destroy = true
    versioning    = false
    file_key      = "file_local_name.env"
    file_path     = "file_in_bucket_name.env"
  }

  vpc          = {} # ...
  orchestrator = {} # ...
  traffics     = [] # ...
}
