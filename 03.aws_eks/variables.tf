locals {
  cluster_version = "1.31"
  region          = "ap-northeast-2"
  vpc_cidr        = "10.21.0.0/16"
  azs             = [for az in data.aws_availability_zones.available.names : az if az == "ap-northeast-2a" || az == "ap-northeast-2c"]
  az_short = {
    "ap-northeast-2a" = "apn2a"
    "ap-northeast-2c" = "apn2c"
  }

  # 공통 태그
  owner       = "junholee"
  project     = "eks-demo"
  environment = "dev"
  managed_by  = "Terraform"

  common_tags = {
    Owner       = local.owner
    Project     = local.project
    Environment = local.environment
    ManagedBy   = local.managed_by
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "EKS API 엔드포인트에 접근을 허용할 CIDR 리스트"
  type        = list(string)
  default = [
    "220.118.41.211/32", # 맥북 Local 접근용
    "75.2.98.97/32",     # TFC API
    "99.83.150.238/32"   # TFC API
  ]
}