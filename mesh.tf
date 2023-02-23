##########################################################################
##########################################################################
#--- This file contains all the virtual resources (Service discovery) ---#
##########################################################################
##########################################################################

resource "aws_service_discovery_service" "discovery_srv" {
  name = "${var.env_name}"
  dns_config {
    namespace_id = var.namespace_id
    dns_records {
      ttl  = 300
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

# This Gateway-Route will be created by setting the var "access_by_gateway_route" to true (required for orcestrators only).
resource "aws_appmesh_gateway_route" "gw_route_1" {
  count = var.access_by_gateway_route == true ? 1: 0
  provider             = aws.app_mesh
  name                 = "gw-${var.app_mesh_name}-${local.prefix}-route"
  mesh_name            = var.app_mesh_name
  mesh_owner           = var.app_mesh_account_id
  virtual_gateway_name = "gw-${var.app_mesh_name}"

  spec {
    http_route {
      action {
        target {
          virtual_service {
            virtual_service_name = aws_appmesh_virtual_service.virtual_service_1.name
          }
        }
      }

      match {
        prefix = var.env_name == var.app_mesh_name ? "/${var.app_name}" : "/${var.env_name}/${var.app_name}"
      }
    }
  }
}

resource "aws_appmesh_virtual_router" "virtual_route_1" {
  name       = "vr-${var.app_name}-${var.env_name}"
  mesh_name  = "${var.app_mesh_name}"
  mesh_owner = "${var.app_mesh_account_id}"

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }
  }
}


resource "aws_appmesh_virtual_service" "virtual_service_1" {
  name       = "${var.env_name}.${var.namespace}"
  mesh_name  = "${var.app_mesh_name}"
  mesh_owner = "${var.app_mesh_account_id}"

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.virtual_route_1.name
      }
    }
  }
}

resource "aws_appmesh_route" "service_route" {
  name                = "route-${var.app_name}-${var.env_name}"
  mesh_name           = "${var.app_mesh_name}"
  mesh_owner          = "${var.app_mesh_account_id}"
  virtual_router_name = aws_appmesh_virtual_router.virtual_route_1.name
  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = "vn-${local.prefix}-green"
          weight       = 100
        }
        weighted_target {
          virtual_node = "vn-${local.prefix}-blue"
          weight       = 0
        }
      }
    }
  }
  depends_on = [
    aws_appmesh_virtual_node.blue_green_virtual_nodes
  ]
  # Ignoring changes made by code_deploy controller
  lifecycle {
    ignore_changes = [
      spec[0].http_route[0].action
    ]
  }
}

resource "aws_appmesh_virtual_node" "blue_green_virtual_nodes" {
  for_each   = toset(["blue", "green"])

  name       = "vn-${var.app_name}-${var.env_name}-${each.key}"
  mesh_name  = var.app_mesh_name
  mesh_owner = "${var.app_mesh_account_id}"
  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }

    dynamic "backend" {
      for_each = var.backends
      content {
        virtual_service {
          virtual_service_name = "${backend.value}.${var.app_mesh_name}.${var.tribe_name}.local"
        }
      }
    }
    dynamic "backend" {
      for_each = var.external_services
      content {
        virtual_service {
          virtual_service_name = "${backend.value}"
        }
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = var.env_name
        namespace_name = var.namespace

        attributes = {
          "ECS_SERVICE_NAME" = "${var.app_name}-${var.env_name}-${each.key}"
        }      
      }
    }

    logging {
      access_log {
        file {
          path = "/dev/stdout"
        }
      }
    }
  }
}


#--- Virtual services for external_services ---#
resource "aws_appmesh_virtual_service" "external_service_virtualservice" {
  for_each  = toset(local.external_services_list)
  name      = "${each.key}"
  mesh_name = var.app_mesh_name
  mesh_owner = var.app_mesh_account_id
  spec {
    provider {
      virtual_router {
        # virtual_router_name = "vr-questionnaire-net-qas"
        virtual_router_name = "vr-${var.app_name}-${var.env_name}"
      }
    }
  }
}
