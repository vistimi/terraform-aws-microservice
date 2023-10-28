SHELL:=/bin/bash
.SILENT:
MAKEFLAGS += --no-print-directory
MAKEFLAGS += --warn-undefined-variables
.ONESHELL:

PATH_ABS_ROOT=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))


fmt: ## Format all files
	terraform fmt -recursive

aws-auth: ## Add credentials
	aws configure set aws_access_key_id ${AWS_ACCESS_KEY}
	aws configure set aws_secret_access_key ${AWS_SECRET_KEY}
	aws configure set region ${AWS_REGION_NAME}
	aws configure set output 'text'
	aws configure list

prepare: ## create temporary provider files
	cat <<-EOF > ${PATH_ABS_ROOT}/provider_aws_override.tf
	provider "aws" {
		region = "${AWS_REGION_NAME}"
		allowed_account_ids = ["${AWS_ACCOUNT_ID}"]
	}
	# provider "kubernetes" {
	#     host                   = one(values(module.eks)).cluster_endpoint
	#     cluster_ca_certificate = base64decode(one(values(module.eks)).cluster.certificate_authority_data)

	#     exec {
	#       api_version = "client.authentication.k8s.io/v1beta1"
	#       command     = "aws"
	#       # This requires the awscli to be installed locally where Terraform is executed
	#       args = ["eks", "get-token", "--cluster-name", one(values(module.eks)).cluster.name]
	#     }
	# }
	# provider "kubectl" {
	#     host                   = one(values(module.eks)).cluster_endpoint
	#     cluster_ca_certificate = base64decode(one(values(module.eks)).cluster.certificate_authority_data)

	#     exec {
	#       api_version = "client.authentication.k8s.io/v1beta1"
	#       command     = "aws"
	#       # This requires the awscli to be installed locally where Terraform is executed
	#       args = ["eks", "get-token", "--cluster-name", one(values(module.eks)).cluster.name]
	#     }
	# }
	EOF

clean-local: ## Clean the local files and folders
	echo "Delete state files..."; for filePath in $(shell find . -type f -name "*.tfstate"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete state backup files..."; for folderPath in $(shell find . -type f -name "terraform.tfstate.backup"); do echo $$folderPath; rm -Rf $$folderPath; done; \
	echo "Delete override files..."; for filePath in $(shell find . -type f -name "*_override.*"); do echo $$filePath; rm $$filePath; done; \
	echo "Delete lock files..."; for folderPath in $(shell find . -type f -name ".terraform.lock.hcl"); do echo $$folderPath; rm -Rf $$folderPath; done;

	echo "Delete temp folder..."; for folderPath in $(shell find . -type d -name ".terraform"); do echo $$folderPath; rm -Rf $$folderPath; done;