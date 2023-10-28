ARG VARIANT=alpine:3.16

#---------------------------------
#       BUILDER ALPINE
#---------------------------------
FROM ${VARIANT} as builder-alpine

ARG TARGETOS TARGETARCH

RUN apk update
RUN apk add -q --no-cache zip wget

# terraform
ARG TERRAFORM_VERSION=1.6.2
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip \
    && unzip terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip && mv terraform /usr/local/bin/terraform \
    && chmod +rx /usr/local/bin/terraform && rm terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip

# # cloud-nuke
# ARG CLOUD_NUKE_VERSION=0.31.1
# RUN wget -q https://github.com/gruntwork-io/cloud-nuke/releases/download/v${CLOUD_NUKE_VERSION}/cloud-nuke_${TARGETOS}_${TARGETARCH} \
#     && mv cloud-nuke_${TARGETOS}_${TARGETARCH} /usr/local/bin/cloud-nuke \
#     && chmod +rx /usr/local/bin/cloud-nuke

#-------------------------
#    RUNNER
#-------------------------
FROM ${VARIANT} as runner

RUN apk update
RUN apk add -q --no-cache make gcc libc-dev bash docker coreutils yq jq github-cli aws-cli curl

# # cloud-nuke
# COPY --from=builder-alpine /usr/local/bin/cloud-nuke /usr/local/bin/cloud-nuke
# RUN cloud-nuke --version

# terraform
COPY --from=builder-alpine /usr/local/bin/terraform /usr/local/bin/terraform
RUN terraform --version

# tflint
COPY --from=ghcr.io/terraform-linters/tflint:latest /usr/local/bin/tflint /usr/local/bin/tflint
RUN tflint --version

# aws cli
RUN aws --version
