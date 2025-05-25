terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.102.0"
    }
    tfe = {
      version = "~> 0.63.0"
    }
  }
}

provider "tfe" {
  hostname     = var.hcp_tf_host_name # Optional, defaults to Terraform Cloud `app.terraform.io`
  token        = var.hcp_tf_api_token
  organization = var.hcp_tf_org_name
}
