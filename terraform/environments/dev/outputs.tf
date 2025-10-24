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

output "argocd_health" {
  value = {
    insecure     = module.argocd.server_insecure
    branch       = module.argocd.target_branch
    app_of_apps  = module.argocd.app_of_apps_path
    repo         = module.argocd.repo_url
  }
}
