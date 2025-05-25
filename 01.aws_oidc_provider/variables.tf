variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "access_key" {
  description = "AWS Access Key"
  type        = string
}

variable "secret_key" {
  description = "AWS Secret Key"
  type        = string
}

variable "tfc_aws_audience" {
  type        = string
  default     = "aws.workload.identity"
  description = "AWS에서 실행 ID 토큰을 검증할 때 사용할 audience 값"
}

variable "tfc_hostname" {
  type        = string
  default     = "app.terraform.io"
  description = "HCP Terraform의 호스트 이름"
}

variable "tfc_allowed_subjects" {
  type        = list(string)
  description = "Terraform Cloud에서 허용되는 sub 조건 리스트"
  default = [
    "organization:junholee_org:project:spoonlabs_pj:workspace:aws_eks:run_phase:*",
    "organization:junholee_org:project:spoonlabs_pj:workspace:aws_eks_addon:run_phase:*",
  ]
}