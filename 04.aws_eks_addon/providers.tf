provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks_workspace.outputs.eks_cluster_endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_workspace.outputs.eks_cluster_ca_data)
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.eks_workspace.outputs.eks_cluster_name
}