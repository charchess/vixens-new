resource "null_resource" "health" {
  depends_on = [helm_release.cilium]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} rollout status deploy/cilium-operator
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} wait pods -l k8s-app=cilium --for=condition=ready --timeout=120s

      rm -f "$TMP_KUBECONFIG"
    EOF
    environment = { KUBECONFIG_RAW = var.kubeconfig_raw }
  }
}

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

resource "helm_release" "cilium" {
  depends_on = [null_resource.wait_api]   # <- attend l’API

  name             = "cilium"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true
  values           = [local.final_values]
  wait             = var.wait
  timeout          = var.timeout
}