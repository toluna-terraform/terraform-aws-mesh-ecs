# Current AWS region
data "aws_region" "current" {}

# Current AWS account
data "aws_caller_identity" "current" {  }


# App Mesh policy
data "aws_iam_policy_document" "appmesh_role_policy" {
  statement {
    actions   = [
          "appmesh:*"
        ]
    resources = ["arn:aws:appmesh:*:*:mesh/*"]
  }
}

data "aws_ssm_parameter" "security_cidr" {
  name = "/infra/tgw/route_cidr"
}

# Check if initial image exists
data "external" "current_service_image" {
  program = ["${path.module}/files/get_container_image.sh"]
  query = {
    app_name = "${var.app_name}"
    image_name = "${var.app_container_image}"
    aws_profile = "${var.aws_profile}"
  }
}