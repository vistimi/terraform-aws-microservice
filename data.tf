data "aws_vpc" "current" {
  id = var.vpc.id
}

data "aws_subnets" "tier" {
  for_each = var.vpc.subnet_tier_ids == null ? { 0 = {} } : {}

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.current.id]
  }
  tags = {
    Tier = var.vpc.tag_tier
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) >= 2
      error_message = "For a Load Balancer: At least two tier subnets in two different Availability Zones must be specified, tier: ${var.vpc.tag_tier}, subnets: ${jsonencode(self.ids)}"
    }
  }
}

data "aws_subnets" "intra" {
  for_each = var.vpc.subnet_intra_ids == null && var.orchestrator.eks != null ? { 0 = {} } : {}

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.current.id]
  }
  tags = {
    Tier = "intra"
  }

  lifecycle {
    postcondition {
      condition     = length(self.ids) >= 2
      error_message = "For a Load Balancer: At least two intra subnets in two different Availability Zones must be specified, tier: intra, subnets: ${jsonencode(self.ids)}"
    }
  }
}

locals {
  vpc = {
    id               = var.vpc.id
    subnet_tier_ids  = coalesce(var.vpc.subnet_tier_ids, data.aws_subnets.tier[0].ids)
    subnet_intra_ids = coalesce(var.vpc.subnet_intra_ids, try(data.aws_subnets.intra[0].ids, null), [])
  }
}
