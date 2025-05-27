############################################################################
# HCP Terraform Settings를 위한 변수
############################################################################
variable "hcp_tf_host_name" {
  description = "HCP Terraform URL"
  type        = string
  default     = "app.terraform.io"
}

variable "hcp_tf_org_name" {
  default = "HCP Terraform ORG 기입"
  type    = string
}

variable "hcp_tf_api_token" {
  default = "HCP Terraform API Token"
  type    = string
}

variable "vcs_info" {
  description = "연동될 VCS의 정보 기입(TFC/TFE에 등록될 VCS Connection 이름 은 map(key)로 설정)"
  type = map(object({
    api_token        = string
    api_url          = string
    http_url         = string
    service_provider = string
  }))
}

variable "hcp_tf_project_name" {
  description = "TFC/TFE에 생성할 Project 이름 기입"
  type        = string
  default     = "spoonlabs_pj"
}

variable "hcp_tf_workspace_vcs" {
  description = "생성할 워크스페이스의 연동할 vcs repo 주소와 실행 모드 기입"
  type = map(object({
    vcs_repo_identifier = string
    execution_mode      = string
    working_directory   = string
    trigger_patterns    = list(string)
    auto_apply          = bool
    global_remote_state = bool
    workspace_tag_name  = list(string)
  }))
  default = {
    aws_eks = {
      vcs_repo_identifier = "jhlee-terraform/aws_eks"
      working_directory   = "/03.aws_eks"
      trigger_patterns    = ["/03.aws_eks/**/*"]
      auto_apply          = false
      global_remote_state = true
      workspace_tag_name  = ["leejunho"]
      execution_mode      = "remote"
    }
    aws_eks_addon = {
      vcs_repo_identifier = "jhlee-terraform/aws_eks"
      working_directory   = "/04.aws_eks_addon"
      trigger_patterns    = ["/04.aws_eks_addon/**/*"]
      auto_apply          = false
      global_remote_state = true
      workspace_tag_name  = ["leejunho"]
      execution_mode      = "remote"
    }
  }
}


data "terraform_remote_state" "oidc_provider" {
  backend = "local"
  config = {
    path = "../01.aws_oidc_provider/terraform.tfstate"
  }
}

locals {
  variable_sets = {
    # AWS Provider Variable Set
    aws_provider_var_set = {
      name = "AWS Provider VarSet"
      variables = {
        TFC_AWS_RUN_ROLE_ARN = {
          value       = data.terraform_remote_state.oidc_provider.outputs.tfc_aws_run_role_arn
          sensitive   = false
          category    = "env"
          description = "HCP Terraform에서 실행할 AWS 역할 ARN"
        }
        TFC_AWS_PROVIDER_AUTH = {
          value       = "true"
          sensitive   = false
          category    = "env"
          description = "AWS 프로바이더 인증 활성화 설정"
        }
      }
    }
  }
}