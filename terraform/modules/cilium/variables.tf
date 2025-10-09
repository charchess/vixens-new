variable "kubeconfig_raw" {
  description = "Raw kubeconfig content for cluster access"
  type        = string
  sensitive   = true
}

variable "cilium_version" {
  type        = string
  description = "Cilium chart version to install"
  default     = "1.18.2"
}

variable "cilium_values" {
  type        = string
  description = "Custom values for Cilium Helm chart"
  default     = ""
}

variable "namespace" {
  type        = string
  description = "Namespace to install Cilium"
  default     = "kube-system"
}

variable "wait_for_ready" {
  type        = bool
  description = "Wait for Cilium to be ready"
  default     = true
}