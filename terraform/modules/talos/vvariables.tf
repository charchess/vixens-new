variable "cluster_endpoint" {
  type        = string
  description = "API endpoint (https://vip:6443) used to reach cluster API"

  validation {
    condition     = can(regex("^https://[^:]+:[0-9]+$", var.cluster_endpoint))
    error_message = "Cluster endpoint must be in format https://host:port"
  }
}

variable "talos_certs" {
  description = "Talos client certificates (base64 or PEM)"
  type = object({
    ca   = string
    cert = string
    key  = string
  })

  validation {
    condition = alltrue([
      var.talos_certs.ca != "",
      var.talos_certs.cert != "",
      var.talos_certs.key != ""
    ])
    error_message = "All certificate fields must be non-empty."
  }
}

variable "controlplane_config" {
  description = "Controlplane configuration"
  type = object({
    yaml_path = string
    nodes = map(object({
      ip            = string
      hostname      = string
      install_disk  = string
      patch_content = string
    }))
  })
}

variable "bootstrap_node_ip" {
  type        = string
  description = "IP of the node to use for bootstrap"
}

variable "cilium_config" {
  description = "Cilium configuration for inline manifests"
  type = object({
    enabled          = bool
    manifest_content = string
  })
  default = {
    enabled          = false
    manifest_content = ""
  }
}
