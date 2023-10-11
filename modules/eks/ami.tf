locals {
  # https://docs.aws.amazon.com/eks/latest/userguide/retrieve-ami-id.html
  ami_ssm_name = {
    amazon-linux-2-x86_64-cpu = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2/recommended/image_id"
    amazon-linux-2-x86_64-gpu = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2-gpu/recommended/image_id"

    amazon-linux-2-arm64-cpu = "/aws/service/eks/optimized-ami/${var.eks.cluster_version}/amazon-linux-2-arm64/recommended/image_id"

    amazon-bottlerocket-latest-x86_64-cpu = "/aws/service/bottlerocket/aws-k8s-1.27/x86_64/latest/image_id"
    amazon-bottlerocket-latest-x86_64-gpu = "/aws/service/bottlerocket/aws-k8s-1.27-nvidia/x86_64/latest/image_id"

    amazon-bottlerocket-latest-arm64-cpu = "/aws/service/bottlerocket/aws-k8s-1.27/arm64/latest/image_id"
    amazon-bottlerocket-latest-arm64-gpu = "/aws/service/bottlerocket/aws-k8s-1.27-nvidia/arm64/latest/image_id"
  }
}

data "aws_ssm_parameter" "eks_optimized_ami_id" {
  # TODO: handle no ec2
  name = local.ami_ssm_name[join("-", ["amazon", var.eks.group.ec2.os, var.eks.group.ec2.os_version, var.eks.group.ec2.architecture, var.eks.group.ec2.processor_type])]
}

locals {
  image_id = data.aws_ssm_parameter.eks_optimized_ami_id.value
}
