variable "kubeconfig_raw" {
  type        = string
  sensitive   = true
  description = "Kubeconfig brut (sortie talos_cluster.kubeconfig_raw)"
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace cible"
}

variable "chart_version" {
  type        = string
  default     = "1.15.3"
  description = "Version du chart Cilium"
}

variable "extra_values" {
  type        = string
  default     = ""
  description = "YAML brut à merger avec les valeurs par défaut (peut être vide)"
}

variable "wait" {
  type        = bool
  default     = true
  description = "Attendre la disponibilité complète"
}

variable "timeout" {
  type        = number
  default     = 600
  description = "Timeout d’attente (s)"
}