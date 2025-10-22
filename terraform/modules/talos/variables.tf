variable "cluster_endpoint" { type = string }
variable "talos_certs" {
  type = object({ ca = string, cert = string, key = string })
}
variable "controlplane_yaml" { type = string }   # contenu brut
variable "nodes" {
  type = map(object({
    ip           = string
    hostname     = string
    install_disk = string
    patch        = string   # contenu brut
  }))
}
variable "bootstrap_node_ip" { type = string }
variable "cilium_config" {
  type = object({ enabled = bool, manifest = string })
  default = { enabled = false, manifest = "" }  # CNI remplacement par défaut
}
variable "timeouts" {
  type = object({ apply = number, bootstrap = number, destroy = number })
  default = { apply = 600, bootstrap = 600, destroy = 300 }
}