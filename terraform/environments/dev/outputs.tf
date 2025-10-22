output "kubeconfig" {
  description = "Generated kubeconfig for cluster access"
  value       = module.talos.kubeconfig_raw
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Cluster API endpoint"
  value       = module.talos.cluster_endpoint
}

output "node_ips" {
  description = "Map of node names to their IPs"
  value       = module.talos.node_ips
}

output "bootstrap_status" {
  description = "Cluster bootstrap status"
  value       = module.talos.bootstrap_status
}