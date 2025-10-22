output "installed" {
  value = helm_release.cilium.status == "deployed"
}
output "namespace" {
  value = helm_release.cilium.namespace
}
output "version" {
  value = helm_release.cilium.version
}