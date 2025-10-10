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
  value = {
    for name, node in var.controlplane_config.nodes : name => node.ip
  }
}

output "bootstrap_status" {
  description = "Cluster bootstrap status"
  value = {
    bootstrapped = talos_machine_bootstrap.this.id != ""
    timestamp    = talos_machine_bootstrap.this.id
  }
}


output "health_status" {
  description = "Cluster health check status"
  value = {
    nodes_configured = length(talos_machine_configuration_apply.controlplanes)
    bootstrap_done   = talos_machine_bootstrap.this.id != ""
    api_available    = length(null_resource.wait_api) > 0
    checks_enabled   = var.enable_post_deploy_checks
  }
}


output "deployment_status" {
  description = "Overall deployment status"
  value = {
    cluster_endpoint = var.cluster_endpoint
    nodes_count      = length(var.controlplane_config.nodes)
    cilium_enabled   = var.cilium_config.enabled
    ready            = length(null_resource.post_deploy_checks) > 0
  }
}

