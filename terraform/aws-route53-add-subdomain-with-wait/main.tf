provider "aws" {
    region     = "${var.AWS_REGION}"
}

locals {
    lb_name = "${replace(var.SANDBOX_DNS, "/(.*?)(-\\d+)(\\..+?\\.elb\\.amazonaws\\.com$)/", "$1")}" 
}

data "aws_route53_zone" "primary_zone" {
    name = "${var.DNS_ZONE_NAME}"          # "test.com."
    private_zone="${var.IS_PRIVATE_ZONE}"
}

data "aws_lb" "sandbox_alb" {
    name = "${local.lb_name}"
}

resource "null_resource" "wait_until_subdomain_doesnt_exist" {
    provisioner "local-exec" {
        command = "chmod 777 wait_until_subdomain_doesnt_exist.sh && ./wait_until_subdomain_doesnt_exist.sh '${var.DNS_ZONE_NAME}' '${var.SUBDOMAIN}' '${data.aws_route53_zone.primary_zone.zone_id}'"
        interpreter = ["/bin/bash", "-c"]
  }
}

resource "aws_route53_record" "sub_domain" {
    zone_id = "${data.aws_route53_zone.primary_zone.zone_id}" # Replace with your zone ID
    name    = "${var.SUBDOMAIN}" # "sub.example.com" # Replace with your name/domain/subdomain
    type    = "A"
    alias {
        name                   = "${var.SANDBOX_DNS}"
        zone_id                = "${data.aws_lb.sandbox_alb.zone_id}"
        evaluate_target_health = true
    }

    depends_on = ["null_resource.wait_until_subdomain_doesnt_exist"]
}