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

# Containers env vars
data "template_file" "app_container_environment" {
    template = file("${path.module}/templates/app_env_vars.json")
    vars = { APP_NAME = "${var.app_name}", 
    BACKENDS_LIST = "${var.backends}",
    ENV_NAME = "${var.env_name}", 
    APP_MESH_ACCOUNT_ID = "${var.app_mesh_account_id}",
    APP_MESH_PROFILE = "${var.app_mesh_profile}",
    EXTERNAL_SERVICES = "${var.external_services}",
    BACKEND_SERVICES = "${var.backends}"}
}


data "template_file" "envoy_container_environment" {
  template = file("${path.module}/templates/envoy_env_vars.json")
  vars = { APP_NAME = "${var.app_name}", 
    APP_MESH_NAME = "${var.app_mesh_name}" }
}


data "template_file" "datadog_container_environment" {
  template = file("${path.module}/templates/datadog_env_vars.json")
  vars = { 
    APP_NAME = "${var.app_name}", 
    APP_MESH_PROFILE = "${var.app_mesh_profile}",
    APP_MESH_NAME = "${var.app_mesh_name}" }
}

