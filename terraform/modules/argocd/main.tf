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

#resource "null_resource" "force_uninstall" {
#  triggers = {
#    kubeconfig_raw = var.kubeconfig_raw
#    namespace      = var.namespace
#  }

#  provisioner "local-exec" {
#    when    = destroy
#    command = <<-EOF
#      set -euo pipefail
#      TMP_KUBECONFIG=$(mktemp)
#      echo "${self.triggers.kubeconfig_raw}" > "$TMP_KUBECONFIG"
#      chmod 600 "$TMP_KUBECONFIG"

#      kubectl --kubeconfig="$TMP_KUBECONFIG" delete helmrelease argocd -n ${self.triggers.namespace} --ignore-not-found=true || true
#      kubectl --kubeconfig="$TMP_KUBECONFIG" delete ns ${self.triggers.namespace} --ignore-not-found=true --timeout=30s || true
#      echo "✅ ArgoCD force-uninstalled"
#      rm -f "$TMP_KUBECONFIG"
#    EOF
#  }
#}

resource "null_resource" "verify_state" {
  depends_on = [helm_release.argocd, kubectl_manifest.app_of_apps]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      set -euo pipefail
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "🔍 Checking ArgoCD server mode..."
      INSECURE=$(kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} get deploy argocd-server -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -q -- "--insecure" && echo true || echo false)
      [[ "$INSECURE" == "${var.server_insecure}" ]] || { echo "❌ Insecure mismatch"; exit 1; }

      echo "🔍 Checking target branch in App-of-Apps..."
      BRANCH=$(kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} get application apps -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "")
      [[ "$BRANCH" == "${var.target_branch}" ]] || { echo "❌ Branch mismatch (expected ${var.target_branch}, got $BRANCH)"; exit 1; }

      echo "✅ ArgoCD state matches desired config"
      rm -f "$TMP_KUBECONFIG"
    EOF
    environment = { KUBECONFIG_RAW = var.kubeconfig_raw }
  }
}

#resource "null_resource" "delete_admin_secret" {
#  depends_on = [helm_release.argocd]

#  provisioner "local-exec" {
#    interpreter = ["/bin/bash", "-c"]
#    command     = <<-EOF
#      TMP_KUBECONFIG=$(mktemp)
#      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
#      chmod 600 "$TMP_KUBECONFIG"
#      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} delete secret argocd-secret --ignore-not-found=true
#      rm -f "$TMP_KUBECONFIG"
#    EOF
#    environment = { KUBECONFIG_RAW = var.kubeconfig_raw }
#  }
#}

resource "kubectl_manifest" "app_of_apps" {
  provider   = kubectl.argocd
  count      = var.app_of_apps_path != "" ? 1 : 0
  depends_on = [helm_release.argocd]

  yaml_body = local.rendered
}