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

locals {
  cilium_manifest = file("${path.module}/cilium.yaml")
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
    file(each.value.patch_path),
    templatefile("${path.module}/cilium.yaml.tftpl", {
      cilium_manifest = local.cilium_manifest
    })
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

#resource "null_resource" "untaint_not_ready" {
#  depends_on = [talos_cluster_kubeconfig.this]
#
#  provisioner "local-exec" {
#    interpreter = ["/bin/bash", "-c"]
#    command     = <<-EOT
#      set -e
#      export KUBECONFIG=$(mktemp)
#      echo "$KUBECONFIG_RAW" > "$KUBECONFIG"
#      chmod 600 "$KUBECONFIG"
#      for node in $(kubectl get nodes --no-headers | awk '{print $1}'); do
#        kubectl taint nodes "$node" node.kubernetes.io/not-ready:NoSchedule- || true
#      done
#      rm -f "$KUBECONFIG"
#    EOT
#    environment = {
#      KUBECONFIG_RAW = talos_cluster_kubeconfig.this.kubeconfig_raw
#    }
#  }
#
#  triggers = {
#    kubeconfig_raw = talos_cluster_kubeconfig.this.kubeconfig_raw
#  }
#}

# on applique cilium
#resource "helm_release" "cilium" {
#  depends_on = [null_resource.untaint_not_ready]
#
#  name       = "cilium"
#  repository = "https://helm.cilium.io"
#  chart      = "cilium"
#  version    = "1.17.8"
#  namespace  = "kube-system"
#  wait   = true
#
#  values = [file("${path.module}/values-cilium.yaml")]
#}

#resource "null_resource" "post_cilium_fixes" {
#  depends_on = [helm_release.cilium]
#
#  provisioner "local-exec" {
#    interpreter = ["/bin/bash", "-c"]
#    command     = <<-EOT
#      set -e
#      export KUBECONFIG=$(mktemp)
#      echo "$KUBECONFIG_RAW" > "$KUBECONFIG"
#      chmod 600 "$KUBECONFIG"
#
#      # 1. enlève le taint NotReady (revenu après apply)
#      for node in $(kubectl get nodes --no-headers | awk '{print $1}'); do
#        kubectl taint nodes "$node" node.kubernetes.io/not-ready:NoSchedule- || true
#      done
#
#      # 2. retire l'init-container clean-cilium-state (revenu après apply)
#      kubectl -n kube-system patch ds/cilium --type=json \
#        -p='[{"op":"remove","path":"/spec/template/spec/initContainers/4"}]' || true
#
#      rm -f "$KUBECONFIG"
#    EOT
#    environment = {
#      KUBECONFIG_RAW = talos_cluster_kubeconfig.this.kubeconfig_raw
#    }
#  }
#
#  triggers = {
#    kubeconfig_raw = talos_cluster_kubeconfig.this.kubeconfig_raw
#  }
#}



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

