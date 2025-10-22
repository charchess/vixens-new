variable "kubeconfig_raw" {
  type        = string
  sensitive   = true
  description = "Kubeconfig brut (sortie talos_cluster.kubeconfig_raw)"
}

variable "repo_url" {
  type        = string
  description = "Repo Git contenant les apps à déployer"
  default     = "https://github.com/votre-org/manifests.git"
}

variable "target_branch" {
  type        = string
  description = "Branche à synchroniser (dev, prod, ...)"
  default     = "main"
}

variable "namespace" {
  type        = string
  default     = "argocd"
  description = "Namespace cible"
}

variable "lb_ip" {
  type        = string
  default     = ""
  description = "IP statique pour le service LoadBalancer (vide = DHCP)"
}

variable "chart_version" {
  type        = string
  default     = "8.5.8"
  description = "Version du chart argo-cd"
}

variable "extra_values" {
  type        = string
  default     = ""
  description = "YAML brut à merger avec les valeurs par défaut"
}