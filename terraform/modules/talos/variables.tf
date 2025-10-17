variable "health_check_timeout" {
  type        = number
  description = "Timeout for node health checks in seconds"
  default     = 300
}

variable "bootstrap_timeout" {
  type        = number
  description = "Timeout for cluster bootstrap in seconds"
  default     = 300
}

variable "api_wait_timeout" {
  type        = number
  description = "Timeout for API server readiness in seconds"
  default     = 300
}

variable "enable_post_deploy_checks" {
  type        = bool
  description = "Enable post-deployment health checks"
  default     = true
}

variable "node_health_check_timeout" {
  type        = number
  description = "Timeout per health check in seconds"
  default     = 30
}

variable "node_health_max_retries" {
  type        = number
  description = "Maximum number of health check retries"
  default     = 12
}

variable "node_health_retry_delay" {
  type        = number
  description = "Delay between health check retries in seconds"
  default     = 30
}

variable "bootstrap_max_retries" {
  type        = number
  description = "Maximum number of bootstrap verification retries"
  default     = 15
}

variable "bootstrap_retry_delay" {
  type        = number
  description = "Delay between bootstrap verification retries in seconds"
  default     = 20
}

variable "bootstrap_check_timeout" {
  type        = number
  description = "Timeout for each bootstrap check in seconds"
  default     = 45
}

