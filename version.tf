terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }

    # Tests versions
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }

    # Kubernetes versions
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
