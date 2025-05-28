output "cert_arn" {
  description = "ACM 인증서 ARN"
  value = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "route53_zone_id" {
  description = "Route53 호스팅 존 ID"
  value       = aws_route53_zone.hosting_zone.zone_id
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_cluster_endpoint" {
  description = "EKS API 서버 엔드포인트 (Helm provider host)"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_data" {
  description = "EKS 클러스터 CA 인증서(base64, Helm provider cluster_ca_certificate)"
  value       = module.eks.cluster_certificate_authority_data
}

