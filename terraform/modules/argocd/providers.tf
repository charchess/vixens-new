provider "kubectl" {
  alias = "argocd"

  host                   = yamldecode(var.kubeconfig_raw).clusters[0].cluster.server
  cluster_ca_certificate = base64decode(yamldecode(var.kubeconfig_raw).clusters[0].cluster["certificate-authority-data"])
  client_certificate     = base64decode(yamldecode(var.kubeconfig_raw).users[0].user["client-certificate-data"])
  client_key             = base64decode(yamldecode(var.kubeconfig_raw).users[0].user["client-key-data"])
}