data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  account_arn = data.aws_caller_identity.current.arn
  dns_suffix  = data.aws_partition.current.dns_suffix // amazonaws.com
  partition   = data.aws_partition.current.partition  // aws
  region_name = data.aws_region.current.name

  # icmp, icmpv6, tcp, udp, or all use the protocol number
  # https://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml
  layer7_to_layer4_mapping = {
    http    = "tcp"
    https   = "tcp"
    tcp     = "tcp"
    udp     = "udp"
    tcp_udp = "tcp"
    ssl     = "tcp"
  }

  ecr_services = {
    private = "ecr"
    public  = "ecr-public"
  }

  os_to_ecs_os_mapping = {
    linux = "LINUX"
  }
  arch_to_ecs_arch_mapping = {
    x86_64 = "X86_64"
    arm64  = "ARM64"
  }
}
