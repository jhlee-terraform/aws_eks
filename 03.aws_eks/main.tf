############################################################################
# AWS 기본 데이터 소스 및 EKS AMI 정보 조회
# - 현재 AWS 계정 정보
# - 사용 가능한 AZ 목록
# - EKS 노드용 AMI 정보 조회
############################################################################
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

data "aws_ami" "eks_default" {
  # most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    # values = ["amazon-eks-node-${local.cluster_version}-v*"]
    # https://github.com/awslabs/amazon-eks-ami/releases 참고
    values = ["amazon-eks-node-al2023-x86_64-standard-1.31-v20250519"]
  }
}


############################################################################
# VPC 및 네트워크 리소스 생성
# - VPC, 퍼블릭/프라이빗 서브넷, NAT 게이트웨이 등
############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.owner}-${local.project}-vpc"
  cidr = local.vpc_cidr
  azs  = local.azs

  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 8, i)]
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 8, i + 32)]

  public_subnet_names    = [for az in local.azs : "${local.owner}-${local.project}-public-${local.az_short[az]}"]
  private_subnet_names   = [for az in local.azs : "${local.owner}-${local.project}-private-${local.az_short[az]}"]
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  create_egress_only_igw = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.common_tags.Project
  }
}


############################################################################
# EKS 클러스터 및 관련 리소스 생성
# - EKS 클러스터, 노드 그룹, 클러스터 애드온, KMS, access_entries 등
############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name                         = "${local.owner}-${local.project}-eks-cluster"
  cluster_version                      = local.cluster_version
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  cluster_addons = {
    coredns = {
      addon_version = "v1.11.4-eksbuild.14"
    }
    kube-proxy = {
      addon_version = "v1.31.7-eksbuild.7"
    }
    vpc-cni = {
      addon_version = "v1.19.5-eksbuild.3"

      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  create_kms_key                  = true
  kms_key_description             = "EKS Secret Encryption Key"
  enable_kms_key_rotation         = true
  kms_key_deletion_window_in_days = 7
  kms_key_aliases                 = ["alias/eks-secret-key"]

  cluster_encryption_config = {
    resources = ["secrets"]
  }

  authentication_mode = "API_AND_CONFIG_MAP"
  access_entries = {
    hcp_terraform_admin = {
      principal_arn     = "arn:aws:iam::154551172320:role/hcp-terraform-role"
      kubernetes_groups = []
      type              = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    eks_admin_access = {
      principal_arn     = aws_iam_role.eks_admin_access.arn
      kubernetes_groups = []
      type              = "STANDARD"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64"

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  eks_managed_node_groups = {
    addon = {
      # By default, the module creates a launch template to ensure tags are propagated to instances, etc.,
      # so we need to disable it to use the default template provided by the AWS EKS managed node group service
      use_custom_launch_template = false

      name            = "${local.owner}-${local.project}-managed-ng"
      use_name_prefix = false
      description     = "Node group for Karpenter, EBS CSI, LB Controller, ExternalDNS and other system addons"

      instance_types       = ["m7i.large", "m7i-flex.large"]
      force_update_version = true
      capacity_type        = "ON_DEMAND" # "SPOT"

      min_size     = 2
      max_size     = 2
      desired_size = 2

      ami_id     = data.aws_ami.eks_default.image_id
      subnet_ids = module.vpc.private_subnets
      # disk_size  = 50

      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 30
            volume_type = "gp3"
            iops        = 3000
            throughput  = 150
            encrypted   = false
            # kms_key_id            = module.ebs_kms_key.key_arn
            delete_on_termination = true
          }
        }
      }

      create_iam_role          = true
      iam_role_name            = "${local.owner}-${local.project}-managed-ng-role"
      iam_role_use_name_prefix = false
      iam_role_description     = "managed node group role"
      iam_role_tags = {
        Purpose = "Protector of the kubelet"
      }
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        additional                         = aws_iam_policy.node_additional.arn
      }
      tags = { Name = "${local.owner}-${local.project}-system-ng" }
    }
  }
}

resource "aws_iam_policy" "node_additional" {
  name        = "${local.project}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


############################################################################
# EKS VPC CNI용 IRSA 역할 및 관련 리소스 생성
# - VPC CNI용 IAM Role, OIDC Provider 매핑 등
############################################################################
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

}