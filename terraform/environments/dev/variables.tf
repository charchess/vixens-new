variable "cluster_endpoint" { type = string }
variable "talos_certs" {
  type = object({ ca = string, cert = string, key = string })
}
variable "bootstrap_node_ip" { type = string }
variable "controlplanes" {
  type = map(object({
    ip          = string
    hostname    = string
    install_disk = string
    patch_file  = string # seul le nom du fichier
  }))
}

variable "enable_cilium" {
  type        = bool
  default     = true
  description = "Installer Cilium après bootstrap Talos"
}

variable "env_name" {
  type        = string
  default     = "dev"
  description = "Nom de l’environnement (dev, prod, …) → branche Git"
}

variable "argocd_lb_ip" {
  type        = string
  default     = ""
  description = "IP statique pour ArgoCD LB (vide = DHCP)"
}

variable "argocd_repo_url" {
  type        = string
  default     = "https://github.com/charchess/vixens-new"
}

variable "argocd_app_of_apps_path" {
  type        = string
  default     = "bootstrap/apps-dev.yaml"
}

variable "argocd_server_insecure" {
  type        = bool
  default     = true
  description = "Désactive TLS + auth pour dev"
}

variable "argocd_server_url" {
  type        = string
  default     = "http://192.168.111.163:30080"  # VIP de dev
  description = "URL d’accès au serveur ArgoCD (dev)"
}

variable "argocd_template_vars" {
  type        = map(string)
  default = {
    BRANCH   = "dev"
    REPO_URL = "https://github.com/charchess/vixens-new"
  }
  description = "Variables injectées dans le template App-of-Apps"
}