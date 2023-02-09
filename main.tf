##########################################################################
##########################################################################
#---------- This file contains ECS resources and Security group ---------#
##########################################################################
##########################################################################

locals {
    prefix = "${var.app_name}-${var.env_name}"
    security_cidr = split(",", data.aws_ssm_parameter.security_cidr.value)
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
  name = "${local.prefix}"
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
    registry_arn = aws_service_discovery_service.discovery_srv.arn
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
  for_each = toset(["blue", "green"])
  family                   = "${local.prefix}-${each.key}"
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  container_definitions = jsonencode([
      {
            name = var.app_name
            image = var.app_container_image
            cpu = var.task_definition_cpu
            memory = var.task_definition_memory
            essential = true
            # environment = split (",", replace(jsonencode(local.app_env_vars), "{BG_COLOR}", each.key) )
            environment = local.app_env_vars
            secrets = var.app_container_secrets
            taskRoleArn = aws_iam_role.ecs_task_execution_role.arn
            portMappings = [
                {
                    containerPort = var.app_container_port
                    hostPort = var.app_container_port
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = var.aws_cloudwatch_log_group_name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "${var.app_name}-logs"
                }
            }
            
      },

      # --- Envoy container definitino --- #
      {        
          name = "envoy"
          image = "public.ecr.aws/appmesh/aws-appmesh-envoy:v1.24.0.0-prod"
          essential = true
          taskRoleArn = aws_iam_role.ecs_task_execution_role.arn
          environment = local.envoy_env_vars
          healthCheck = {
              command = [
                  "CMD-SHELL",
                  "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
              ]
              startPeriod = 10
              interval = 5
              timeout = 2
              retries = 3
          }
          user = "1337"
          portMappings =  []
          logConfiguration = {
              logDriver = "awslogs"
              options = {
                  awslogs-group = var.aws_cloudwatch_log_group_name
                  awslogs-region = data.aws_region.current.id
                  awslogs-stream-prefix = "envoy-logs"
              }
          }
      },

      # --- Datadog container definitino --- #
      {        
          name = var.datadog_container_name
          image = var.datadog_container_image
          essential = true
          secrets = [{ "name" : "DD_API_KEY", "valueFrom" : "/${data.aws_caller_identity.current.account_id}/datadog/api-key" }]
          environment = local.datadog_env_vars
          taskRoleArn = aws_iam_role.ecs_task_execution_role.arn
          healthCheck = {
              command = [
                  "CMD-SHELL",
                  "agent health"
              ]
              startPeriod = 10
              interval = 5
              timeout = 2
              retries = 3
          }
          user = "1337"
          portMappings =  [
              {
                  containerPort = var.datadog_container_port
                  hostPort = var.datadog_container_port
              }
          ]
          logConfiguration = {
              logDriver = "awslogs"
              options = {
                  awslogs-group = var.aws_cloudwatch_log_group_name
                  awslogs-region = data.aws_region.current.id
                  awslogs-stream-prefix = "datadog-logs"
              }
          }
      }
    ])
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = var.task_definition_cpu
  memory                   = var.task_definition_memory
  proxy_configuration {
    type           = "APPMESH"
    container_name = "envoy"
    properties = {
      AppPorts         = var.envoy_container_port
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




