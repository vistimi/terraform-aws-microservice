ARG VARIANT=alpine:3.16
ARG ALPINE_VARIANT=alpine:3.16
ARG GO_ALPINE_VARIANT=golang:1.19.0-alpine

#---------------------------------
#       BUILDER ALPINE
#---------------------------------
FROM ${ALPINE_VARIANT} as builder-alpine

ARG TARGETOS TARGETARCH

RUN apk update
RUN apk add -q --no-cache zip wget

# terraform
ARG TERRAFORM_VERSION=1.5.2
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip \
    && unzip terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip && mv terraform /usr/local/bin/terraform \
    && chmod +rx /usr/local/bin/terraform && rm terraform_${TERRAFORM_VERSION}_${TARGETOS}_${TARGETARCH}.zip

# cloud-nuke
ARG CLOUD_NUKE_VERSION=0.31.1
RUN wget -q https://github.com/gruntwork-io/cloud-nuke/releases/download/v${CLOUD_NUKE_VERSION}/cloud-nuke_${TARGETOS}_${TARGETARCH} \
    && mv cloud-nuke_${TARGETOS}_${TARGETARCH} /usr/local/bin/cloud-nuke \
    && chmod +rx /usr/local/bin/cloud-nuke

#---------------------------------
#    BUILDER ALPINE GOLANG
#---------------------------------
FROM ${GO_ALPINE_VARIANT} as builder-alpine-go

#-------------------------
#    RUNNER
#-------------------------
FROM ${VARIANT} as runner

RUN apk update
RUN apk add -q --no-cache bash aws-cli

# Golang setup
COPY --from=builder-alpine-go /usr/local/go/ /usr/local/go/
COPY --from=builder-alpine-go /go/ /go/
ENV GOPATH /go
ENV PATH /usr/local/go/bin:$GOPATH/bin:$PATH
RUN mkdir -p $GOPATH/src $GOPATH/bin && chmod -R 777 $GOPATH
WORKDIR $GOPATH
RUN go version

# cloud-nuke
COPY --from=builder-alpine /usr/local/bin/cloud-nuke /usr/local/bin/cloud-nuke
RUN cloud-nuke --version

# terraform
COPY --from=builder-alpine /usr/local/bin/terraform /usr/local/bin/terraform
RUN terraform --version

# tflint
COPY --from=ghcr.io/terraform-linters/tflint:latest /usr/local/bin/tflint /usr/local/bin/tflint
RUN tflint --version

# aws cli
RUN aws --version
