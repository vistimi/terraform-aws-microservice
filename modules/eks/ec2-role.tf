# locals {
#   create_ec2 = var.eks.group.ec2 != null ? { "${var.name}" = {} } : {}
# }

# # Create AWS worker iam role.
# resource "aws_iam_role" "worker_iam_role" {
#   for_each = local.create_ec2

#   name                  = format("%s-eks-worker-role", var.name)
#   force_detach_policies = true
#   tags                  = var.tags
#   assume_role_policy = jsonencode({
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ec2.amazonaws.com"
#         }
#       }
#     ]
#     Version = "2012-10-17"
#   })
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # Create AWS workernode iam role policy attachment.
# resource "aws_iam_role_policy_attachment" "WorkerNode_iam_role_policy_attachment" {
#   for_each = local.create_ec2

#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#   role       = aws_iam_role.worker_iam_role[each.key].name
# }

# # Create AWS iam role CNI policy attachment.
# resource "aws_iam_role_policy_attachment" "CNI_policy_iam_role_policy_attachment" {
#   for_each = local.create_ec2

#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
#   role       = aws_iam_role.worker_iam_role[each.key].name
# }

# # Create AWS EC2Container registry read only iam role policy attachment.
# resource "aws_iam_role_policy_attachment" "EC2ContainerRegistryReadOnly_iam_role_policy_attachment" {
#   for_each = local.create_ec2

#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#   role       = aws_iam_role.worker_iam_role[each.key].name
# }

# # Create AWS iam instance profile group.
# resource "aws_iam_instance_profile" "iam_instance_profile" {
#   for_each = local.create_ec2

#   name = format("%s-eks-instance-profile", var.name)
#   role = aws_iam_role.worker_iam_role[each.key].name

#   lifecycle {
#     create_before_destroy = true
#   }
# }
