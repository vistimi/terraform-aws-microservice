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

# the name of the VPC to use
VPC_ID=***

# if you want to use route53
DOMAIN_NAME=name
DOMAIN_SUFFIX=com

# for gRPC testing, either 'x86_64' or 'amd64'
ARCH=x86_64
```