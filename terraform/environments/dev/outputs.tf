output "kubeconfig" {
  description = "Generated kubeconfig for cluster access"
  value       = module.talos_cluster.kubeconfig_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = module.talos_cluster.cluster_endpoint
}

output "node_ips" {
  description = "Map of node names to their IPs"
  value       = module.talos_cluster.node_ips
}

output "bootstrap_status" {
  description = "Cluster bootstrap status"
  value       = module.talos_cluster.bootstrap_status
}
