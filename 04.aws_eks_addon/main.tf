data "terraform_remote_state" "eks_workspace" {
  backend = "remote"

  config = {
    organization = local.tfc_org_name
    workspaces = {
      name = local.tfc_workspace_eks
    }
  }
}

module "load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "load-balancer-controller-${data.terraform_remote_state.eks_workspace.outputs.eks_cluster_name}"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = "${data.terraform_remote_state.eks_workspace.outputs.eks_oidc_provider_arn}"
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "external_dns_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                     = "external-dns-${data.terraform_remote_state.eks_workspace.outputs.eks_cluster_name}"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/${data.terraform_remote_state.eks_workspace.outputs.route53_zone_id}"]

  oidc_providers = {
    ex = {
      provider_arn               = "${data.terraform_remote_state.eks_workspace.outputs.eks_oidc_provider_arn}"
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "ebs-csi-${data.terraform_remote_state.eks_workspace.outputs.eks_cluster_name}"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = "${data.terraform_remote_state.eks_workspace.outputs.eks_oidc_provider_arn}"
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "helm_release" "aws_ebs_csi_driver" {
  name = "aws-ebs-csi-driver"

  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = "2.24.0"

  values = [
    templatefile("${path.module}/custom-values-yaml/ebs_csi_values.yaml",
      {
        ebs-csi-controller-role-arn = module.ebs_csi_irsa_role.iam_role_arn,
      }
    )
  ]
}

resource "helm_release" "load_balancer_controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.6.2" # https://github.com/aws/eks-charts/tree/gh-pages
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/custom-values-yaml/lb_controller_values.yaml",
      {
        load_balancer_controller_role_arn = module.load_balancer_controller_irsa_role.iam_role_arn,
        eks_cluster_name                  = data.terraform_remote_state.eks_workspace.outputs.eks_cluster_name,
      }
    )
  ]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns"
  chart      = "external-dns"
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/custom-values-yaml/external_dns_values.yaml",
      {
        txtOwnerId            = data.terraform_remote_state.eks_workspace.outputs.route53_zone_id,
        domainFilters         = [local.domain_name],
        external_dns_role_arn = module.external_dns_irsa_role.iam_role_arn,
      }
    )
  ]
}