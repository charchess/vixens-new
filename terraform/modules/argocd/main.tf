resource "null_resource" "wait_api" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      until kubectl --kubeconfig="$TMP_KUBECONFIG" get nodes >/dev/null 2>&1; do
        echo "⏳ Waiting for Kubernetes API ..."
        sleep 10
      done
      echo "✅ Kubernetes API reachable"
      rm -f "$TMP_KUBECONFIG"
    EOF
    environment = { KUBECONFIG_RAW = var.kubeconfig_raw }
  }
}

resource "helm_release" "argocd" {
  depends_on = [null_resource.wait_api]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  values           = [local.final_values]
  wait             = true
  timeout          = 600

  # IP statique si fournie
  set = var.lb_ip != "" ? [
    {
      name  = "server.service.loadBalancerIP"
      value = var.lb_ip
    }
  ] : []
}