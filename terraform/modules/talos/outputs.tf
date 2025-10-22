output "kubeconfig_raw" {
  description = "Raw kubeconfig content for cluster access"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = var.cluster_endpoint
}

output "node_ips" {
  description = "Map of node names to their IPs"
  value = { for k, v in var.nodes : k => v.ip }
}

output "bootstrap_status" {
  description = "Cluster bootstrap status"
  value = { bootstrapped = talos_machine_bootstrap.this.id != "" }
}