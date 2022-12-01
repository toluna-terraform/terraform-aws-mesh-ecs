##########################################################################
##########################################################################
#---------- This file contains ECS resources and Security group ---------#
##########################################################################
##########################################################################

locals {
    prefix = "${var.app_name}-${var.env_name}"
    security_cidr = split(",", data.aws_ssm_parameter.security_cidr.value)
    app_container_environment     = jsonencode(data.template_file.app_container_environment)
    envoy_container_environment     = jsonencode(data.template_file.envoy_container_environment)
    datadog_container_environment     = jsonencode(data.template_file.datadog_container_environment)
    external_services_list = var.is_orchestrator == true ? var.external_services : []
}

#--- Provider for Mesh owner profile ---#
provider "aws" {
  alias   = "app_mesh"
  profile = "${var.app_mesh_profile}"
  region = data.aws_region.current.name
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
  container_definitions = jsonencode([
        local.main_task,
        local.envoy_task,
        var.enable_datadog == true ? local.datadog_task : null
    ])
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


