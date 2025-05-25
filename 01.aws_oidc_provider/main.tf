############################################################################
# HCP Terraform OIDC Provider 설정
# HCP Terraform (TFC)와 AWS IAM OpenID Connect Provider (OIDC) 연동을 위한 설정
############################################################################

data "tls_certificate" "tfc_certificate" {
  url = "https://${var.tfc_hostname}"
}

############################################################################
# AWS IAM OpenID Connect Provider 생성
# HCP Terraform의 OIDC Provider를 AWS에 등록하여, TFC에서 AWS IAM 역할을 Assume할 수 있도록 설정
############################################################################
resource "aws_iam_openid_connect_provider" "tfc_provider" {
  url             = data.tls_certificate.tfc_certificate.url
  client_id_list  = [var.tfc_aws_audience]
  thumbprint_list = [data.tls_certificate.tfc_certificate.certificates[0].sha1_fingerprint]
}


############################################################################
# AWS IAM Role 생성 (TFC에서 AWS AssumeRole 수행 가능)
# HCP Terraform에서 특정 AWS 리소스에 접근할 수 있도록 IAM 역할 생성
############################################################################
resource "aws_iam_role" "tfc_role" {
  name               = "hcp-terraform-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.tfc_provider.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${var.tfc_hostname}:aud": "${one(aws_iam_openid_connect_provider.tfc_provider.client_id_list)}"
        },
        "ForAnyValue:StringLike": {
          "${var.tfc_hostname}:sub": [
            ${join(",", [for subject in var.tfc_allowed_subjects : "\"${subject}\""])}
          ]
        }
      }
    }
  ]
}
EOF
}


############################################################################
# AWS IAM Role에 관리자 정책 (AdministratorAccess) 연결
############################################################################
resource "aws_iam_role_policy_attachment" "tfc_policy_attachment" {
  role = aws_iam_role.tfc_role.name
  # policy_arn = aws_iam_policy.tfc_policy.arn
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}