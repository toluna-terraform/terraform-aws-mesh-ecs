locals {
    # --- App container environment variables --- #
    app_env_vars = [
    { "name" = "NODE_DEBUG"
      "value" : "debug" 
    },
    { "name" = "NODE_NAME"
      "value" = "vn-${var.app_name}-${var.env_name}-{BG_COLOR}" 
    },
    { "name" = "MESH_NAME"
      "value" = "${var.app_mesh_name}" 
    },
    { "name" = "MESH_OWNER"
      "value" = "${var.app_mesh_account_id}" 
    },
    { "name" = "SERVICE_NAME"
      "value" = "${var.app_name}-${var.env_name}" 
    },
    { "name" = "DD_ENV"
      "value" = "${var.app_mesh_name}.${var.app_mesh_account_id}" 
    },
    { "name"  = "DD_INTEGRATIONS"
      "value" = "/opt/datadog/integrations.json" 
    },
    { "name" = "DD_RUNTIME_METRICS_ENABLED"
      "value" = "true" 
    },
    { "name" = "DD_SERVICE"
      "value" = "${var.app_name}-${var.env_name}" 
    },
    { "name" = "DD_TRACE_SAMPLE_RATE"
      "value" : "1" 
    },
    { "name" = "DD_VERSION"
      "value" = "0.0.1" 
    },
    { "name" = "ENABLE_ENVOY_DATADOG_TRACING"
      "value" = "true" 
    },
    { "name" = "ENVOY_LOG_LEVEL"
      "value" = "debug" 
    },
    { "name" = "DATADOG_TRACER_PORT"
      "value" = "8126" 
    },
    { "name" = "DD_TRACE_AGENT_PORT"
      "value" = "8126" 
    },
    { "name" = "DD_AGENT_HOST"
      "value" = "localhost" 
    },
    { "name" = "DD_CLOUD_PROVIDER_METADATA"
      "value" = "aws" 
    },
    { "name" = "DD_TAGS"
      "value" = "service:${var.app_name},env:${var.app_mesh_name}.${var.app_mesh_profile},version:0.0.1,source:${var.app_name}" 
    },
    { "name" = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
      "value" = "true" 
    },
    { "name" = "ECS_FARGATE"
      "value" = "true" 
    },
    { "name" = "ASPNETCORE_ENVIRONMENT"
      "value" = "${var.env_name}" 
    },
    { "name" = "EXTERNAL_SERVICES"
      "value" = "${var.external_services}" 
    },
    { "name" = "BACKEND_SERVICES"
      "value" = "${var.backends}" 
    }
    ]   

    # --- Datadog container environment variables --- #
    datadog_env_vars = [
    { "name" = "DD_ENV"
      "value" = "${var.app_mesh_name}.${var.app_mesh_profile}" 
    },
    { "name" = "DD_SERVICE"
      "value" = "${var.app_name}" 
    },
    { "name" = "DD_VERSION"
      "value" = "0.0.1"
    },
    { "name" = "DD_APM_DD_URL"
      "value" = "https://trace.agent.datadoghq.com" 
    },
    { "name" = "DD_APM_ENABLED"
      "value" = "true" 
    },
    { "name" = "DD_APM_NON_LOCAL_TRAFFIC"
      "value" = "true" 
    },
    { "name" = "DD_DOCKER_ENV_AS_TAGS"
      "value" = "true" 
    },
    { "name" = "DD_DOCKER_LABELS_AS_TAGS"
      "value" = "true" 
    },
    { "name" = "ECS_FARGATE"
      "value" = "true" 
    },
    { "name" = "DD_SITE"
      "value" = "datadoghq.com" 
    },
    { "name" = "DD_USE_PROXY_FOR_CLOUD_METADATA"
      "value" = "true" 
    }
  ]

    # --- Envoy container environment variables --- #
    envoy_env_vars = [
    { "name" = "APPMESH_RESOURCE_ARN"
      "value" = "arn:aws:appmesh:us-east-1:${data.aws_caller_identity.current.id}:mesh/${var.app_mesh_name}@${var.app_mesh_account_id}/virtualNode/vn-${var.app_name}-${var.env_name}-{BG_COLOR}" 
    },
    { "name" = "ENABLE_ENVOY_DATADOG_TRACING"
      "value" = "true" 
    },
    { "name" = "ENVOY_LOG_LEVEL"
      "value" = "off" 
    },
    { "name" = "DATADOG_TRACER_PORT"
      "value" = "8126" 
    }
  ]

    # --- App container definitino --- #
    app_task = {
            name = var.app_name,
            image = var.app_container_image,
            cpu = var.task_definition_cpu,
            memory = var.task_definition_memory,
            essential = true,
            #environment = concat(local.app_env_vars,var.app_environment_variables)
            #environment = local.app_env_vars
            #environment = [{"name": "environment", "value": "${local.app_env_vars}"}]
            #environment = jsonencode(local.app_env_vars)
            "environment": local.app_env_vars,
            secrets = var.app_container_secrets,
            taskRoleArn = aws_iam_role.ecs_task_execution_role.arn,
            portMappings = [
                {
                    containerPort = var.app_container_port
                    hostPort = var.app_container_port
                }
            ],
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = var.aws_cloudwatch_log_group_name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "${var.app_name}-logs"
                }
            },
            dependsOn = [{
                containerName = "envoy"
                condition = "HEALTHY"
            }]
            
        }
    
    # --- Envoy container definitino --- #
    envoy_task = {        
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
            },
            user = "1337",
            portMappings =  [],
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = var.aws_cloudwatch_log_group_name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "envoy-logs"
                }
            }
        }
    
    # --- Datadog container definitino --- #
    datadog_task = {        
            name = var.datadog_container_name,
            image = var.datadog_container_image,
            essential = true,
            secrets = [{ "name" : "DD_API_KEY", "valueFrom" : "/${data.aws_caller_identity.current.account_id}/datadog/api-key" }],
            "environment": local.datadog_env_vars,
            taskRoleArn = aws_iam_role.ecs_task_execution_role.arn,
            healthCheck = {
                command = [
                    "CMD-SHELL",
                    "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"
                ]
                startPeriod = 10
                interval = 5
                timeout = 2
                retries = 3
            },
            user = "1337",
            portMappings =  [
                {
                    containerPort = var.datadog_container_port
                    hostPort = var.datadog_container_port
                }
            ],
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = var.aws_cloudwatch_log_group_name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "datadog-logs"
                }
            },
        }
}
