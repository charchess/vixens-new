output "kubeconfig" {
  description = "Generated kubeconfig for cluster access"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = var.cluster_endpoint
}

output "controlplane_nodes" {
  description = "List of configured controlplane nodes"
  value = {
    for name, node in var.controlplanes : name => {
      ip       = node.ip
      hostname = node.hostname
    }
  }
}
