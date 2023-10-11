data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  dns_suffix = data.aws_partition.current.dns_suffix // amazonaws.com
  partition  = data.aws_partition.current.partition  // aws
  region_name = data.aws_region.current.name

  bucket_name = join("-", [var.name, "env"])

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
    {
      test     = "ForAnyValue"
      variable = "aws:PrincipalServiceNamesList"
      values   = ["ec2.amazonaws.com", "ecs.amazonaws.com", "eks.amazonaws.com"]
    },
    {
      test = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${local.partition}:*:${local.region_name}:${local.account_id}:*${var.name}*",
      ]
    }
  ]
}

resource "aws_kms_key" "objects" {
  for_each = var.encryption != null ? { "${var.name}" = {} } : {}

  description             = "KMS key is used to encrypt bucket objects"
  deletion_window_in_days = var.encryption.deletion_window_in_days

  tags = var.tags
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.11.0"

  bucket = local.bucket_name
  # acl    = "private"  # no need if policy is tight

  versioning = var.versioning ? {
    enabled = true
  } : {}

  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy.json
  force_destroy = var.force_destroy

  # control_object_ownership = true
  # object_ownership         = "ObjectWriter"

  server_side_encryption_configuration = var.encryption != null ? {
    rule = {
      apply_server_side_encryption_by_default = {
        kms_master_key_id = aws_kms_key.objects[var.name].arn
        sse_algorithm     = "aws:kms"
      }
    }
  } : {}

  tags = var.tags
}

data "aws_iam_policy_document" "bucket_policy" {
  dynamic "statement" {
    for_each = concat(
      local.iam_statements,
      var.encryption != null ? [
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