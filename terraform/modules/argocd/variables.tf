variable "argocd_lb_ip" {
  description = "IP statique pour le service LoadBalancer d'ArgoCD (vide = DHCP)"
  type        = string
  default     = ""
}
