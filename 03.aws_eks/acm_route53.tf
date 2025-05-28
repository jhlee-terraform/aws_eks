############################################################################
# ACM(인증서) 및 Route53(DNS) 관련 리소스 생성
# - 도메인 인증용 ACM, DNS 레코드, 인증 검증 등
############################################################################
resource "aws_acm_certificate" "cert" {
  domain_name       = local.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${local.domain_name}"
  ]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.route53_record : record.fqdn]
}

resource "aws_route53_zone" "hosting_zone" {
  name = local.domain_name
}

resource "aws_route53_record" "route53_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.hosting_zone.zone_id
}

resource "aws_ecr_repository" "ecr" {
  name                 = "${local.owner}-${local.project}-ecr-repo"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "${local.owner}-${local.project}-ecr-repo"
  }
}