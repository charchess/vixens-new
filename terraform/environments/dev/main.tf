terraform {
  required_version = ">= 1.0"
  required_providers {
    talos = { source = "siderolabs/talos", version = "~> 0.9.0" }
  }
}

locals {
  kubeconfig = yamldecode(module.talos.kubeconfig_raw)
}

provider "helm" {
  kubernetes = {
    host                   = local.kubeconfig.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
    client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  }
}
module "talos" {
  source = "../../modules/talos"

  cluster_endpoint  = var.cluster_endpoint
  talos_certs       = var.talos_certs
  controlplane_yaml = file("${path.module}/controlplane.yaml")
  bootstrap_node_ip = var.bootstrap_node_ip

  nodes = {
    for k, v in var.controlplanes : k => {
      ip           = v.ip
      hostname     = v.hostname
      install_disk = v.install_disk
      patch        = file("${path.module}/${v.patch_file}")
    }
  }

  cilium_config = {
    enabled  = true
    manifest = file("${path.module}/cilium.yaml")
  }
}


module "cilium" {
  count  = var.enable_cilium ? 1 : 0
  source = "../../modules/cilium"

  kubeconfig_raw = module.talos.kubeconfig_raw
}


module "argocd" {
  source = "../../modules/argocd"

  kubeconfig_raw = module.talos.kubeconfig_raw
  target_branch  = var.env_name          # "dev", "prod", ...
  repo_url       = "https://github.com/votre-org/manifests.git"
  lb_ip          = var.argocd_lb_ip      # laisser vide pour DHCP
}