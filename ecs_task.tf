locals {
    # --- App container environment variables --- #
    app_env_vars = [
    { "name": "NODE_DEBUG",
      "value" : "debug" 
    },
    { "name": "NODE_NAME",
      "value": "vn-${var.app_name}-${var.env_name}-{BG_COLOR}" 
    },
    { "name": "MESH_NAME",
      "value": "${var.app_mesh_name}" 
    },
    { "name": "MESH_OWNER",
      "value": "${var.app_mesh_account_id}" 
    },
    { "name": "SERVICE_NAME",
      "value": "${var.app_name}-${var.env_name}" 
    },
    { "name": "DD_ENV",
      "value": "${var.app_mesh_name}.${var.app_mesh_account_id}" 
    },
    { "name"  = "DD_INTEGRATIONS",
      "value": "/opt/datadog/integrations.json" 
    },
    { "name": "DD_RUNTIME_METRICS_ENABLED",
      "value": "true" 
    },
    { "name": "DD_SERVICE",
      "value": "${var.app_name}-${var.env_name}" 
    },
    { "name": "DD_TRACE_SAMPLE_RATE",
      "value" : "1" 
    },
    { "name": "DD_VERSION",
      "value": "0.0.1" 
    },
    { "name": "ENABLE_ENVOY_DATADOG_TRACING",
      "value": "true" 
    },
    { "name": "ENVOY_LOG_LEVEL",
      "value": "debug" 
    },
    { "name": "DATADOG_TRACER_PORT",
      "value": "8126" 
    },
    { "name": "DD_TRACE_AGENT_PORT",
      "value": "8126" 
    },
    { "name": "DD_AGENT_HOST",
      "value": "localhost" 
    },
    { "name": "DD_CLOUD_PROVIDER_METADATA",
      "value": "aws" 
    },
    { "name": "DD_TAGS",
      "value": "service:${var.app_name},env:${var.app_mesh_name}.${var.app_mesh_profile},version:0.0.1,source:${var.app_name}" 
    },
    { "name": "DD_DOGSTATSD_NON_LOCAL_TRAFFIC",
      "value": "true" 
    },
    { "name": "ECS_FARGATE",
      "value": "true" 
    },
    { "name": "ASPNETCORE_ENVIRONMENT",
      "value": "${var.env_name}" 
    },
    { "name": "EXTERNAL_SERVICES",
      "value": jsonencode("${var.external_services}")
    },
    { "name": "BACKEND_SERVICES",
      "value": jsonencode("${var.backends}")
    }
    ]   

    # --- Datadog container environment variables --- #
    datadog_env_vars = [
    { "name": "DD_ENV",
      "value": "${var.app_mesh_name}.${var.app_mesh_profile}" 
    },
    { "name": "DD_SERVICE",
      "value": "${var.app_name}" 
    },
    { "name": "DD_VERSION",
      "value": "0.0.1"
    },
    { "name": "DD_APM_DD_URL",
      "value": "https://trace.agent.datadoghq.com" 
    },
    { "name": "DD_APM_ENABLED",
      "value": "true" 
    },
    { "name": "DD_APM_NON_LOCAL_TRAFFIC",
      "value": "true" 
    },
    { "name": "DD_DOCKER_ENV_AS_TAGS",
      "value": "true" 
    },
    { "name": "DD_DOCKER_LABELS_AS_TAGS",
      "value": "true" 
    },
    { "name": "ECS_FARGATE",
      "value": "true" 
    },
    { "name": "DD_SITE",
      "value": "datadoghq.com" 
    },
    { "name": "DD_USE_PROXY_FOR_CLOUD_METADATA",
      "value": "true" 
    }
  ]

    # --- Envoy container environment variables --- #
    envoy_env_vars = [
    { "name": "APPMESH_RESOURCE_ARN",
      "value": "arn:aws:appmesh:us-east-1:${data.aws_caller_identity.current.id}:mesh/${var.app_mesh_name}@${var.app_mesh_account_id}/virtualNode/vn-${var.app_name}-${var.env_name}-{BG_COLOR}" 
    },
    { "name": "ENABLE_ENVOY_DATADOG_TRACING",
      "value": "true" 
    },
    { "name": "ENVOY_LOG_LEVEL",
      "value": "off" 
    },
    { "name": "DATADOG_TRACER_PORT",
      "value": "8126" 
    }
  ]


}
