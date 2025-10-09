locals {
  # Determine bootstrap node from controlplane nodes
  bootstrap_node = var.bootstrap_node_ip != "" ? var.bootstrap_node_ip : values(var.controlplane_config.nodes)[0].ip
  
  # Prepare cilium patch if enabled
  cilium_patch = var.cilium_config.enabled ? templatefile("${path.module}/templates/cilium.yaml.tftpl", {
    cilium_manifest = var.cilium_config.manifest_content
  }) : ""
}

# Template file for cilium patch
resource "local_file" "cilium_patch_template" {
  count = var.cilium_config.enabled ? 1 : 0
  
  filename = "${path.cwd}/.terraform/cilium.yaml.tftpl"
  content = file("${path.module}/templates/cilium.yaml.tftpl")
}

# Apply Talos configuration to controlplane nodes
resource "talos_machine_configuration_apply" "controlplanes" {
  for_each = var.controlplane_config.nodes

  node = each.value.ip

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }

  machine_configuration_input = file(var.controlplane_config.yaml_path)

  config_patches = compact([
    each.value.patch_content,
    local.cilium_patch
  ])

  apply_mode = "reboot"
}

# Bootstrap the cluster
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplanes]

  node = local.bootstrap_node

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }
}

# Retrieve cluster kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  node = local.bootstrap_node

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }
}

# Wait for API server readiness
resource "null_resource" "wait_api" {
  depends_on = [talos_cluster_kubeconfig.this]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "Waiting for API server to be ready..."
      until kubectl --kubeconfig="$TMP_KUBECONFIG" get --raw /version >/dev/null 2>&1; do
        sleep 5
      done
      echo "API server is ready"
      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = talos_cluster_kubeconfig.this.kubeconfig_raw
    }
  }
}

# Remove control-plane taints
resource "null_resource" "untaint_controlplanes" {
  depends_on = [null_resource.wait_api]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "Removing control-plane taints..."
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

# Clean node destruction
resource "terraform_data" "node_annihilation" {
  for_each = var.controlplane_config.nodes

  input = {
    node_ip   = each.value.ip
    node_name = each.key
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "💥 Destroying node ${self.input.node_name} (${self.input.node_ip})..."

      timeout 30 talosctl \
        --endpoints ${self.input.node_ip} \
        --nodes ${self.input.node_ip} \
        reset \
        --system-labels-to-wipe STATE,EPHEMERAL \
        --graceful=false \
        --wait=false \
        --reboot || true

      echo "✅ Node ${self.input.node_name} destroyed"
    EOT

    interpreter = ["/bin/bash", "-c"]
  }
}
