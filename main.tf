locals {
    prefix = "${var.app_name}-${var.env_name}"
    security_cidr = split(",", data.aws_ssm_parameter.security_cidr.value)
    
}

#--- Provider for Mesh owner profile ---#
provider "aws" {
  alias   = "app_mesh"
  profile = "${var.app_mesh_profile}"
  region = data.aws_region.current
}

#--- ECS resources ---#
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-${local.prefix}"
}

resource "aws_ecs_service" "main" {
  for_each = toset(["blue","green"])
  name                = "srv-${local.prefix}-${each.key}"
  cluster             = aws_ecs_cluster.ecs_cluster.id
  task_definition     = aws_ecs_task_definition.task_definition[each.key].arn
  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"
  desired_count       = each.key == "green" ? var.ecs_service_desired_count : 0
  deployment_controller {
    type = "ECS"
  }
  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  service_registries {
    registry_arn = aws_service_discovery_service.net.arn
  }

deployment_circuit_breaker {
  enable = true
  rollback = false
}

  # Ignoring changes made by code_deploy controller
  /* lifecycle {
    ignore_changes = [
      task_definition,desired_count
    ]
  } */
}

resource "aws_ecs_task_definition" "task_definition" {
  for_each = toset(["blue","green"])
  family                   = "${local.prefix}-${each.key}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  container_definitions    = "${replace(data.template_file.default-container.rendered, "{BG_COLOR}", each.key)}" 
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = var.task_definition_cpu
  memory                   = var.task_definition_memory
  proxy_configuration {
    type           = "APPMESH"
    container_name = "envoy"
    properties = {
      AppPorts         = var.envoy_app_ports
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "${local.prefix}-ecs"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = local.security_cidr
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-${local.prefix}-ecs"
  }
}



#--- Virtual resources (Mesh) ---#
resource "aws_service_discovery_service" "net" {
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
  mesh_owner           = var.app_mesh_profile
  virtual_gateway_name = "gw-${var.app_mesh_name}"

  spec {
    http_route {
      action {
        target {
          virtual_service {
            virtual_service_name = aws_appmesh_virtual_service.service.name
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
  mesh_owner = "${var.app_mesh_profile}"

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
  mesh_owner = "${var.app_mesh_profile}"

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
  mesh_owner          = "${var.app_mesh_profile}"
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
  mesh_owner = "${var.app_mesh_profile}"
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
  for_each  = var.is_integrator ? tomap(var.external_services) : {}
  name      = "${each.key}"
  mesh_name = var.env_name
  mesh_owner = var.app_mesh_profile
  spec {
    provider {
      virtual_router {
        # should be changed to integrator:
        virtual_router_name = aws_appmesh_virtual_router.external_service_virtualrouter.name
      }
    }
  }
}

#--- IAM ---#
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "role-ecs-${local.prefix}"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": [
         "ecs-tasks.amazonaws.com",
         "ssm.amazonaws.com",
         "mediastore.amazonaws.com",
         "appmesh.amazonaws.com"
         ]
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ssm-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloud-watch-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "envoy-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
}

resource "aws_iam_role_policy" "app_mesh_policy" {
  name = "policy-appmesh-${local.prefix}"
  role = aws_iam_role.ecs_task_execution_role.name
  policy = data.aws_iam_policy_document.appmesh_role_policy.json
}

resource "aws_iam_role_policy" "datadog_policy" {
  name = "datadog-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}
