# devcontainer

Run locally a container to run the tests locally

## Prerequisites

Create a file named `devcontainer.env` in this directory with the following contents:
```
# the AWS configuration to use
AWS_REGION_NAME=***
AWS_PROFILE_NAME=***
AWS_ACCOUNT_ID=***
AWS_ACCESS_KEY=***
AWS_SECRET_KEY=***

TF_VAR_branch_name=trunk
# the name of the VPC to use
TF_VAR_vpc_id=vpc-0e1e39d24e51100b1

# if you want to use route53
TF_VAR_domain_name=vistimi
TF_VAR_domain_suffix=com
```