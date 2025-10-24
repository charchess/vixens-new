output "server_lb_ip" {
  value = helm_release.argocd.status == "deployed" ? (
    var.lb_ip != "" ? var.lb_ip : "DHCP"
  ) : ""
}

output "namespace" {
  value = var.namespace
}

output "repo_url" {
  value = var.repo_url
}

output "target_branch" {
  value = var.target_branch
}

output "server_insecure" {
  value = var.server_insecure
}

output "app_of_apps_path" {
  value = var.app_of_apps_path
}

