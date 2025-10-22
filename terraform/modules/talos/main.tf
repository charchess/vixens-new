locals {
  talosconfig_yaml = yamlencode({
    context = "talos"
    contexts = {
      talos = {
        endpoints = [var.cluster_endpoint]
        ca        = var.talos_certs.ca
        crt       = var.talos_certs.cert
        key       = var.talos_certs.key
      }
    }
  })
  talosconfig_path = "${path.cwd}/.terraform/talosconfig-${md5(local.talosconfig_yaml)}"
}

resource "local_file" "talosconfig" {
  content         = local.talosconfig_yaml
  filename        = local.talosconfig_path
  file_permission = "0600"
}

resource "talos_machine_configuration_apply" "cp" {
  for_each = var.nodes

  node                      = each.value.ip
  client_configuration = {
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }
  machine_configuration_input = var.controlplane_yaml
  config_patches = compact([
    each.value.patch
#    ,var.cilium_config.enabled ? templatefile("${path.module}/templates/cilium.yaml.tftpl", {}) : ""
  ])
  apply_mode = "reboot"
}

resource "null_resource" "wait_nodes" {
  depends_on = [talos_machine_configuration_apply.cp]
  for_each   = var.nodes

  provisioner "local-exec" {
    command = <<-EOF
      set -e
      NODE_IP=${each.value.ip}
      MAX=30; TRY=0
      until (timeout 2 bash -c "</dev/tcp/$NODE_IP/50000") 2>/dev/null; do
        TRY=$((TRY+1))
        [ $TRY -gt $MAX ] && { echo "❌ Port 50000 still closed after $MAX attempts"; exit 1; }
        echo "⏳ Waiting for Talos API on $NODE_IP (attempt $TRY/$MAX)..."
        sleep 10
      done
      echo "✅ Talos API reachable on $NODE_IP"
      export TALOSCONFIG=${local_file.talosconfig.filename}
      talosctl --endpoints $NODE_IP --nodes $NODE_IP get machineconfig >/dev/null
    EOF
  }
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [null_resource.wait_nodes]

  node = var.bootstrap_node_ip
  client_configuration = {
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  node = var.bootstrap_node_ip
  client_configuration = {
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }
}
resource "terraform_data" "reset" {
  for_each = var.nodes

  input = {
    node_ip       = each.value.ip
    talosconfig_path = local_file.talosconfig.filename
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      talosctl --endpoints ${self.input.node_ip} --nodes ${self.input.node_ip} reset \
        --system-labels-to-wipe STATE,EPHEMERAL \
        --graceful=false --reboot --wait=false
    EOF
    environment = { TALOSCONFIG = self.input.talosconfig_path }
  }
}