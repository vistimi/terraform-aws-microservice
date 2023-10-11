# # Create AWS LabelStudio iam role policy attachment to the worker nodes.
# resource "aws_iam_role_policy_attachment" "microservice_role_policy_attachment" {
#   policy_arn = aws_iam_policy.microservice_iam_policy.arn
#   role       = aws_iam_role.worker_iam_role.name
# }

# # Create AWS iam policy document to create access to the s3 bucket to store LS files(upload, avatars, exports).
# resource "aws_iam_policy" "microservice_iam_policy" {
#   name = format("%s-eks-ls-s3-access", var.name)

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action   = []
#         Effect   = "Allow"
#         Resource = ["*"]
#       },
#     ]
#   })
# }
