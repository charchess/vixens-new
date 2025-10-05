terraform {
  required_providers {
    talos = { source = "siderolabs/talos", version = "0.9.0" }
    helm  = { source = "hashicorp/helm",  version = "3.0.2" }
  }
}

provider "talos" {}

provider "helm" {
  kubernetes = {
    host                   = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster.server
    client_certificate     = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users[0].user.client-certificate-data)
    client_key             = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).users[0].user.client-key-data)
    cluster_ca_certificate = base64decode(yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw).clusters[0].cluster.certificate-authority-data)
  }
}

# on fait un talosctl apply du controlplane.yaml et patch per machine
resource "talos_machine_configuration_apply" "controlplanes" {
  for_each = var.controlplanes

  node = each.value.ip

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }

  machine_configuration_input = file(var.controlplane_yaml_path)

  config_patches = [
    file(each.value.patch_path)
  ]

  apply_mode = "reboot"
}

# on bootstrap (trop vite ?)
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplanes]

  node = values(var.controlplanes)[0].ip

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }

}

# on recupere le kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  node = values(var.controlplanes)[0].ip

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }

}

# on attend que l'api reponde
resource "null_resource" "wait_api" {
  depends_on = [talos_cluster_kubeconfig.this]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "Waiting for API server..."
      until kubectl --kubeconfig="$TMP_KUBECONFIG" get --raw /version >/dev/null 2>&1; do
        sleep 5
      done
      echo "API reachable"
      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = talos_cluster_kubeconfig.this.kubeconfig_raw
    }
  }
}

# on untaint les controlplane (normalement inutile)
resource "null_resource" "untaint_controlplanes" {
  depends_on = [null_resource.wait_api]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "Removing control-plane taints ..."
      for node in $(kubectl --kubeconfig="$TMP_KUBECONFIG" get nodes -l node-role.kubernetes.io/control-plane= -o name); do
        kubectl --kubeconfig="$TMP_KUBECONFIG" taint nodes "$node" node-role.kubernetes.io/control-plane:NoSchedule- || true
      done

      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = talos_cluster_kubeconfig.this.kubeconfig_raw
    }
  }
}

# on applique cilium
resource "helm_release" "cilium" {
  depends_on = [null_resource.untaint_controlplanes]

  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.17.8"
  namespace  = "kube-system"
  wait   = true

  # Talos : kube-proxy désactivé → mode strict kube-proxy-free

  set = [
    { name = "kubeProxyReplacement", value = "strict" },
    { name = "k8sServiceHost",       value = trimsuffix(trimprefix(var.cluster_endpoint, "https://"), ":6443") },
    { name = "k8sServicePort",       value = "6443" },
    { name = "operator.replicas",    value = "1" },
    { name = "operator.tolerations[0].key",      value = "node-role.kubernetes.io/control-plane" },
    { name = "operator.tolerations[0].effect",   value = "NoSchedule" },
    { name = "operator.tolerations[0].operator", value = "Exists" },
    { name = "agent.tolerations[0].key",      value = "node-role.kubernetes.io/control-plane" },
    { name = "agent.tolerations[0].effect",   value = "NoSchedule" },
    { name = "agent.tolerations[0].operator", value = "Exists" }
  ]


}




output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}




resource "null_resource" "reset_before_destroy" {
  # copie des valeurs **au moment de la création**
  triggers = {
    bootstrap_ip = values(var.controlplanes)[0].ip
    talosconfig  = base64encode(talos_cluster_kubeconfig.this.kubeconfig_raw)
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      echo "Resetting node $TRIGGER_BOOTSTRAP_IP ..."
      talosctl --talosconfig <(echo $TRIGGER_TALOSCONFIG | base64 -d) \
               reset -n $TRIGGER_BOOTSTRAP_IP -e $TRIGGER_BOOTSTRAP_IP \
               --system-labels-to-wipe STATE \
               --system-labels-to-wipe EPHEMERAL \
               --graceful=false \
               --wait=false \
               --reboot || true
    EOT
    environment = {
      TRIGGER_BOOTSTRAP_IP = self.triggers.bootstrap_ip
      TRIGGER_TALOSCONFIG  = self.triggers.talosconfig
    }
  }

  depends_on = [talos_cluster_kubeconfig.this]
}

