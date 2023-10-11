data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  dns_suffix  = data.aws_partition.current.dns_suffix // amazonaws.com
  partition   = data.aws_partition.current.partition  // aws
  region_name = data.aws_region.current.name

  bucket_name = "test-env"

  iam_statements = [
    {
      actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
      resources = ["arn:${local.partition}:s3:::${local.bucket_name}"]
      effect    = "Allow"
    },
    {
      actions   = ["s3:GetObject"]
      resources = ["arn:${local.partition}:s3:::${local.bucket_name}/*"]
      effect    = "Allow"
    }
  ]

  iam_conditions = [
    # {
    #   test     = "ForAnyValue"
    #   variable = "aws:PrincipalServiceNamesList"
    #   values   = ["ec2.amazonaws.com", "ecs.amazonaws.com", "eks.amazonaws.com"]
    # },
    {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${local.partition}:*:${local.region_name}:${local.account_id}:*test*",
      ]
    }
  ]
}

data "aws_iam_policy_document" "bucket_policy" {
  dynamic "statement" {
    for_each = concat(
      local.iam_statements,
      true != null ? [
        {
          actions   = ["kms:GetPublicKey", "kms:GetKeyPolicy", "kms:DescribeKey"]
          resources = ["arn:${local.partition}:s3:::${local.bucket_name}"]
          effect    = "Allow"
        },
      ] : []
    )

    content {
      actions   = statement.value.actions
      resources = statement.value.resources
      effect    = statement.value.effect

      principals {
        type        = "Service"
        identifiers = ["ec2.amazonaws.com", "ecs.amazonaws.com", "eks.amazonaws.com"]
      }

      dynamic "condition" {
        for_each = local.iam_conditions

        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

output "name" {
  value = data.aws_iam_policy_document.bucket_policy.json
}
