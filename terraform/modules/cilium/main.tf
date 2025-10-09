locals {
  # Parse kubeconfig to extract cluster info
  kubeconfig = yamldecode(var.kubeconfig_raw)
  cluster_server = local.kubeconfig.clusters[0].cluster.server
  
  # Default Cilium values
  default_values = <<-EOT
    ipam:
      mode: kubernetes
    kubeProxyReplacement: true
    securityContext:
      capabilities:
        ciliumAgent:
          - CHOWN
          - KILL
          - NET_ADMIN
          - NET_RAW
          - IPC_LOCK
          - SYS_ADMIN
          - SYS_RESOURCE
          - DAC_OVERRIDE
          - FOWNER
          - SETGID
          - SETUID
        cleanCiliumState:
          - NET_ADMIN
          - SYS_ADMIN
          - SYS_RESOURCE
    cgroup:
      autoMount:
        enabled: false
      hostRoot: /sys/fs/cgroup
    k8sServiceHost: localhost
    k8sServicePort: 7445
  EOT
  
  # Merge values
  final_values = var.cilium_values != "" ? var.cilium_values : local.default_values
}

provider "helm" {
  kubernetes = {
    host                   = local.cluster_server
    client_certificate     = base64decode(local.kubeconfig.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kubeconfig.users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster.certificate-authority-data)
  }
}

# Install Cilium via Helm
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  namespace  = var.namespace
  wait       = var.wait_for_ready
  timeout    = 600

  values = [local.final_values]
}

# Verify Cilium installation
resource "null_resource" "cilium_verification" {
  depends_on = [helm_release.cilium]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "Verifying Cilium installation..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} wait --for=condition=ready pod -l app.kubernetes.io/name=cilium --timeout=300s
      
      echo "Checking Cilium status..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} exec daemonset/cilium -- cilium status --brief
      
      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = var.kubeconfig_raw
    }
  }
}
