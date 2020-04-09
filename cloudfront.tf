variable "region" {
  default = "us-east-1"
}

locals {
  s3_origin_id = "terraformwebsite"
  aws_acm_certificate_arn = "arn:aws:acm:us-east-1:632369630105:certificate/9fb53418-8ba4-41eb-917a-39993cafabff"
}

data "aws_route53_zone" "garagemdigital" {
  name = "garagemdigital.io."
}

# data "aws_acm_certificate" "cert" {
#   domain   = "garagemdigital.io"
#   types = ["AMAZON_ISSUED"]
# }

provider "aws" {
  shared_credentials_file = "%UserProfile%/.aws/config"
  profile                 = "default"
  region                  = "${var.region}"
}

resource "aws_s3_bucket" "b" {
  bucket = "terraform-website"
  acl    = "public-read"
  policy = "${file("policy.json")}"

  website {
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = "${aws_s3_bucket.b.id}"

  block_public_acls  = true
  ignore_public_acls = true
}

resource "aws_s3_bucket_object" "object" {
  bucket = "${aws_s3_bucket.b.id}"
  key    = "index.html"
  source = "index.html"
  content_type = "text/html"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Criado pelo terraform"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Criado pelo terraform"
  default_root_object = "index.html"

  aliases = ["terraform-website.garagemdigital.io"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  custom_error_response{
    error_code = 403
    response_code = 200
    error_caching_min_ttl = 300
    response_page_path = "/index.html"
  }

  custom_error_response{
    error_code = 404
    response_code = 200
    error_caching_min_ttl = 300
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["BR"]
    }
  }

  tags = {
    Project = "terraform"
  }

   viewer_certificate {
    acm_certificate_arn            = "${local.aws_acm_certificate_arn}"
    cloudfront_default_certificate = "${local.aws_acm_certificate_arn == "" ? true : false}"
    minimum_protocol_version       = "TLSv1"
    ssl_support_method             = "sni-only"
  }
}

resource "aws_route53_record" "cname" {
  zone_id = "${data.aws_route53_zone.garagemdigital.id}"
  name    = "terraform-website"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_cloudfront_distribution.s3_distribution.domain_name}"]
}