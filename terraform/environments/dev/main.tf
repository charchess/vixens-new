# Configure providers
terraform {
  required_version = ">= 1.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }
  }
}

provider "talos" {}

# Read node patch files
locals {
  cilium_manifest = file("${path.module}/cilium.yaml")

  node_patches = {
    obsy  = file("${path.module}/vixens-dev-obsy.yaml")
    onyx  = file("${path.module}/vixens-dev-onyx.yaml")
    opale = file("${path.module}/vixens-dev-opale.yaml")
  }
}

# Deploy Talos cluster
module "talos_cluster" {
  source = "../../modules/talos"

  cluster_endpoint = var.cluster_endpoint
  talos_certs      = var.talos_certs

  # Timeouts augmentés pour environnement lent
  node_health_max_retries   = 15
  node_health_retry_delay   = 45
  node_health_check_timeout = 45
  bootstrap_timeout         = 600
  api_wait_timeout          = 600

  controlplane_config = {
    yaml_path = var.controlplane_yaml_path
    nodes = {
      for name, node in var.controlplanes : name => {
        ip            = node.ip
        hostname      = node.hostname
        install_disk  = node.install_disk
        patch_content = local.node_patches[name]
      }
    }
  }

  bootstrap_node_ip = var.controlplanes.obsy.ip

  cilium_config = {
    enabled          = true
    manifest_content = local.cilium_manifest
  }
}
