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