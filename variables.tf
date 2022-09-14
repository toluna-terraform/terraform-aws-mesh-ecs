# General variables for module
variable "app_name" {
  description = "app name"
  type        = string
}

variable "env_name" {
  description = "environment name"
  type        = string
}

variable "app_mesh_profile" {
  description = "The profile name of the Mesh owner."
  type        = string
}

variable "ecs_service_desired_count" {
  description = "ecs service desired count"
  type        = number
  default = 2
}

variable "subnet_ids" {
  description = "Subnet IDs used in Service"
  type        = list(string)
  default     = null
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}


variable "task_definition_cpu" {
  description = "Task definition CPU"
  type        = number
  default     = 2048
}

variable "task_definition_memory" {
  description = "Task definition memory"
  type        = number
  default     = 4096
}

# Default container related variables
variable "app_container_cpu" {
  description = "Default container cpu"
  type        = number
  default     = 2
}

variable "app_container_memory" {
  description = "Default container memory"
  type        = number
  default     = 4096
}

variable "app_container_port" {
  description = "Default container port"
  type        = number
  default     = 80
}

variable "aws_cloudwatch_log_group_name" {
  description = "Cloud watch log group name"
  type        = string
}

variable "app_container_environment" {
  description = "The environment variables to pass to a container"
  type        = list(map(string))
  default     = []
}

variable "dockerLabels" {
  description = "A key/value map of labels to add to the container"
  type        = map(string)
  default     = {}
}

variable "envoy_container_environment" {
  description = "The environment variables to pass to a container"
  type        = list(map(string))
  default     = []
}

variable "envoy_dockerLabels" {
  description = "A key/value map of labels to add to the container"
  type        = map(string)
  default     = {}
}

variable "app_container_secrets" {
  description = "The secrets to pass to the app container"
  type        = list(map(string))
  default     = []
}

variable "app_container_image" {
  description = "App container image"
  type        = string
}

# Datadog container related variables
variable "create_datadog" {
  description = "Boolean which initiate datadog container creation or not"
  type        = bool
  default     = false
}
variable "datadog_container_cpu" {
  description = "Datadog container cpu"
  type        = number
  default     = 10
}

variable "datadog_container_memoryreservation" {
  description = "Datadog container memory"
  type        = number
  default     = 256
}

variable "datadog_container_port" {
  description = "Datadog container port"
  type        = number
  default     = 8126
}

variable "datadog_container_name" {
  description = "Datadog container name"
  type        = string
  default     = "datadog_agent"
}

variable "datadog_container_image" {
  description = "Datadog container image"
  type        = string
  default     = "datadog/agent:latest"
}

variable "datadog_container_environment" {
  description = "Datadog container environment variables"
  type        = list(map(string))
  default     = []
}

variable "datadog_container_secrets" {
  description = "The secrets to pass to the datadog container"
  type        = list(map(string))
  default     = []
}

variable "datadog_dockerLabels" {
  description = "A key/value map of labels to add to the container"
  type        = map(string)
  default     = {}
}

variable "envoy_app_ports" {
  description = "The app ports for envoy to listen to"
  type  = string
  default = "80"
}

variable "namespace_id" {
  description = "The app namespace id"
  type = string
}

variable "namespace" {
  description = "The app namespac"
  type = string
}

variable "mesh_owner_profile" {
  description = "The profile name of the AppMesh owner."
  type = string
}

variable "app_mesh_name" {
  description = "The mesh name"
  type = string
}

variable "app_mesh_env" {
  description = "The mesh name"
  type = string
}

variable "backends" {
  description = "List of backends for ocastrator"
  type        = list(string)
  default     = []
}

variable "external_services" {
  description = "List of external services for integrator"
  type        = list(string)
  default     = []
}

variable "integrator_external_services" {
  description = "Additional policies to be added to the IAM role"
  type        = list(string)
  default     = []
}

variable "access_by_gateway_route" {
  description = "Boolean which initiates if service is added to App mesh gatway"
  type        = bool
  default     = false
}

variable "tribe_name" {
  description = "e.g. questionnaire"
  type        = string
}

variable "is_integrator" {
  type = boolean 
  description = "Set this var to true if the ECS is the integrator of the Mesh."
}