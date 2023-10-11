# # Create AWS iam role for EKS service.
# resource "aws_iam_role" "iam_role" {
#   name                  = format("%s-eks-role", var.name)
#   force_detach_policies = true
#   tags                  = var.tags
#   assume_role_policy = jsonencode({
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "eks.amazonaws.com"
#         }
#       }
#     ]
#     Version = "2012-10-17"
#   })
#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # create AWS cluster iam role policy attachment.
# resource "aws_iam_role_policy_attachment" "clusterPolicy_iam_role_policy_attachment" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#   role       = aws_iam_role.iam_role.name
# }

# # Create AWS service iam role policy attachment.
# resource "aws_iam_role_policy_attachment" "servicePolicy_iam_role_policy_attachment" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
#   role       = aws_iam_role.iam_role.name
# }

# # Create AWS EKSVPCResourceController iam role policy attachment. Enable Security Groups for Pods.
# # Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
# resource "aws_iam_role_policy_attachment" "EKSVPCResourceController_iam_role_policy_attachment" {
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
#   role       = aws_iam_role.iam_role.name
# }
