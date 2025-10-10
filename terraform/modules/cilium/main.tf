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
  
  # Retry configuration
  max_retries = 5
  retry_delay = 30

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


# Comprehensive Cilium verification
resource "null_resource" "cilium_verification" {
  depends_on = [helm_release.cilium]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "🔍 Verifying Cilium installation..."
      
      # Wait for Cilium pods
      echo "⏳ Waiting for Cilium pods..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} wait --for=condition=ready pod -l app.kubernetes.io/name=cilium --timeout=300s
      
      # Check Cilium status
      echo "🔍 Checking Cilium status..."
      for pod in $(kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} get pods -l app.kubernetes.io/name=cilium -o name); do
        echo "Checking $pod..."
        if ! kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} exec "$pod" -- cilium status --brief; then
          echo "❌ Cilium status check failed for $pod"
          exit 1
        fi
      done
      
      # Verify Cilium operator
      echo "🔍 Checking Cilium operator..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} wait --for=condition=ready pod -l name=cilium-operator --timeout=120s
      
      # Test connectivity
      echo "🔍 Testing cluster connectivity..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" create namespace cilium-test --dry-run=client -o yaml | kubectl apply -f -
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n cilium-test run test-pod --image=busybox --restart=Never -- sleep 30
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n cilium-test wait --for=condition=ready pod/test-pod --timeout=60s
      
      # Cleanup test
      kubectl --kubeconfig="$TMP_KUBECONFIG" delete namespace cilium-test --ignore-not-found=true
      
      echo "✅ Cilium verification completed successfully!"
      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = var.kubeconfig_raw
    }
  }
}

# Cilium connectivity test
resource "null_resource" "cilium_connectivity_test" {
  depends_on = [null_resource.cilium_verification]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "🔍 Running Cilium connectivity tests..."
      
      # Create test deployment
      kubectl --kubeconfig="$TMP_KUBECONFIG" apply -f - <<EOF
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: cilium-test
        namespace: ${var.namespace}
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: cilium-test
        template:
          metadata:
            labels:
              app: cilium-test
          spec:
            containers:
            - name: test
              image: busybox
              command: ["sleep", "3600"]
      EOF
      
      # Wait for deployment
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} wait --for=condition=available deployment/cilium-test --timeout=120s
      
      # Test pod connectivity
      POD1=$(kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} get pods -l app=cilium-test -o name | head -1)
      POD2=$(kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} get pods -l app=cilium-test -o name | tail -1)
      
      echo "Testing pod-to-pod connectivity..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} exec "$POD1" -- ping -c 3 "$POD2"
      
      # Cleanup
      kubectl --kubeconfig="$TMP_KUBECONFIG" -n ${var.namespace} delete deployment cilium-test
      
      echo "✅ Cilium connectivity test passed!"
      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = var.kubeconfig_raw
    }
  }
}
