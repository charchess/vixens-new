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

variable "server_insecure" {
  type        = bool
  default     = false
  description = "Désactiver TLS + auth sur le serveur"
}

variable "app_of_apps_path" {
  type        = string
  default     = ""
  description = "Chemin du manifeste app-of-apps (ex : apps-dev.yaml)"
}

variable "server_url" {
  type        = string
  default     = ""   # laisser vide = auto-detect par ArgoCD
  description = "URL externe à afficher dans l’UI (ex: http://192.168.111.200:30080)"
}

variable "app_of_apps_template_vars" {
  type        = map(string)
  default     = {}
  description = "Variables à injecter dans le template (ex: {BRANCH=dev})"
}

