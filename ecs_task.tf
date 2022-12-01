locals {
    main_task = {
            name = var.app_name
            image = var.app_container_image
            cpu = var.task_definition_cpu
            memory = var.task_definition_memory
            essential = true
            environment = local.app_container_environment == "[]" ? "null" : local.app_container_environment
            secrets = var.app_container_secrets
            taskRoleArn = aws_iam_role.ecs_task_execution_role.arn
            portMappings =  [
                {
                    protocol = "tcp"
                    containerPort = var.app_container_port
                },
                {
                    protocol = "tcp"
                    hostPort = var.app_container_port
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = aws_cloudwatch_log_group.ecs-service.name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "${var.app_name}-logs"
                }
            }
            dependsOn = [{
                containerName = "envoy"
                condition = "HEALTHY"
            }]
            
        }
    
    envoy_task = {        
            name = "envoy"
            image = "840364872350.dkr.ecr.eu-west-1.amazonaws.com/aws-appmesh-envoy:v1.22.0.0-prod"
            essential = true
            taskRoleArn = aws_iam_role.ecs_task_execution_role.arn
            environment = local.envoy_container_environment == "[]" ? "null" : local.envoy_container_environment
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
            portMappings =  [
                {
                    protocol = "tcp"
                    containerPort = var.envoy_container_port
                },
                {
                    protocol = "tcp"
                    hostPort = var.envoy_container_port
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = aws_cloudwatch_log_group.ecs-service.name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "envoy-logs"
                }
            }
        }
    
    datadog_task = {        
            name = var.datadog_container_name
            image = var.datadog_container_image
            essential = true
            secrets = [{ "name" : "DD_API_KEY", "valueFrom" : "/${data.aws_caller_identity.aws_profile.account_id}/datadog/api-key" }]
            environment = local.datadog_container_environment == "[]" ? "null" : local.datadog_container_environment
            taskRoleArn = aws_iam_role.ecs_task_execution_role.arn
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
            portMappings =  [
                {
                    protocol = "tcp"
                    containerPort = var.datadog_container_port
                },
                {
                    protocol = "tcp"
                    hostPort = var.datadog_container_port
                }
            ]
            logConfiguration = {
                logDriver = "awslogs"
                options = {
                    awslogs-group = aws_cloudwatch_log_group.ecs-service.name
                    awslogs-region = data.aws_region.current.id
                    awslogs-stream-prefix = "datadog-logs"
                }
            }
        }
}