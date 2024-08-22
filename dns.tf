data "aws_route53_zone" "this" {
  name = var.dns_zone_name
}

resource "aws_route53_record" "this" {
  name = var.dns_record_name
  type = "CNAME"

  records = [
    aws_lb.this.dns_name,
  ]

  zone_id = data.aws_route53_zone.this.zone_id
  ttl     = "60"
}

resource "aws_acm_certificate" "this" {
  domain_name       = "${var.dns_record_name}.${var.dns_zone_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.web_cert_validation.fqdn]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "web_cert_validation" {
  name = aws_acm_certificate.this.domain_validation_options.0.resource_record_name
  type = aws_acm_certificate.this.domain_validation_options.0.resource_record_type

  records = [aws_acm_certificate.this.domain_validation_options.0.resource_record_value]

  zone_id = data.aws_route53_zone.zone.id
  ttl     = 60

  lifecycle {
    create_before_destroy = true
  }
}