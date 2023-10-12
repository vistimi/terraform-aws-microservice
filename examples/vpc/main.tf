module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-vpc-with-tags"

  vpc = {
    id       = "my_vpc_id"
    tag_tier = "public",
  }

  orchestrator = {} # ...
  traffics     = [] # ...
}

module "microservice" {
  source = "vistimi/microservice/aws"

  name = "microservice-vpc-without-tags"

  vpc = {
    id               = "my_vpc_id"
    subnet_tier_ids  = ["id_subnet_tier_1", "id_subnet_tier_2"]
    subnet_intra_ids = ["id_subnet_intra_1", "id_subnet_intra_2"]
  }

  orchestrator = {} # ...
  traffics     = [] # ...
}
