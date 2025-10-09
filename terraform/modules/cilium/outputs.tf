output "cilium_installed" {
  description = "Whether Cilium was successfully installed"
  value       = helm_release.cilium.status == "deployed"
}

output "cilium_version" {
  description = "Installed Cilium version"
  value       = helm_release.cilium.version
}

output "cilium_namespace" {
  description = "Namespace where Cilium is installed"
  value       = helm_release.cilium.namespace
}
