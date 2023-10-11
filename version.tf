terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.1"
    }
    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = "= 1.14.0"
    # }
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "2.5.0"
    # }
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "2.0.1"
    # }
  }
  required_version = ">= 1.4.0"
}
