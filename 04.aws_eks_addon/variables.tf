locals {
  region          = "ap-northeast-2"

  # 공통 태그
  owner       = "junholee"
  project     = "eks-demo"
  environment = "dev"
  managed_by  = "Terraform"

  domain_name = "mzc-devops.site"

  common_tags = {
    Owner       = local.owner
    Project     = local.project
    Environment = local.environment
    ManagedBy   = local.managed_by
  }

  tfc_org_name = "jhlee-terraform"
  tfc_workspace_eks = "aws-eks"
}