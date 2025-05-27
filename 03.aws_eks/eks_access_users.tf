############################################################################
# Mac에서 EKS 접근을 위한 IAM User 및 Role/Policy 리소스 정의
# - mac-local-user: Mac에서 사용할 IAM User
# - eks-admin-access: EKS 클러스터 접근용 Role (신뢰관계: mac-local-user)
# - 최소 권한 정책 및 역할 연결
############################################################################
resource "aws_iam_user" "mac_local_user" {
  name = "mac-local-user"
}

resource "aws_iam_policy" "assume_role_only" {
  name        = "assume-role-only"
  description = "Allow only sts:AssumeRole"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sts:AssumeRole"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_user_policy_attachment" "mac_local_user_assume_attach" {
  user       = aws_iam_user.mac_local_user.name
  policy_arn = aws_iam_policy.assume_role_only.arn
}

# eks-admin-access Role (EKS 클러스터 접근용, 신뢰관계: mac-local-user)
# - Mac에서 AssumeRole로 이 Role을 사용하여 EKS에 접근
resource "aws_iam_role" "eks_admin_access" {
  name = "eks-admin-access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_user.mac_local_user.arn
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# eks-admin-access Role에 eks:DescribeCluster만 허용
# - kubeconfig 업데이트 및 EKS API 호출 최소 권한
resource "aws_iam_policy" "eks_describe_cluster" {
  name        = "eks-describe-cluster"
  description = "Allow eks:DescribeCluster for kubeconfig update"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "eks:DescribeCluster"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_admin_access_describe_attach" {
  role       = aws_iam_role.eks_admin_access.name
  policy_arn = aws_iam_policy.eks_describe_cluster.arn
}