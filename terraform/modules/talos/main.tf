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

locals {
  # Health check endpoints
  api_health_url = "${replace(var.cluster_endpoint, ":6443", ":50000")}/health"
  
  # Retry configuration
  max_retries = 3
  retry_delay = 10
}

# Bootstrap the cluster
resource "talos_machine_bootstrap" "this" {
  depends_on = [null_resource.talos_api_check]

  node = local.bootstrap_node

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }
}

# Post-bootstrap verification
resource "null_resource" "bootstrap_verification" {
  depends_on = [talos_machine_bootstrap.this]

  triggers = {
    bootstrap_id = talos_machine_bootstrap.this.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "Verifying cluster bootstrap..."
      
      BOOTSTRAP_NODE="${local.bootstrap_node}"
      MAX_RETRIES=15
      RETRY_DELAY=20
      
      # Vérifier que le bootstrap node est joignable et retourne des membres
      retries=0
      while [ $retries -lt $MAX_RETRIES ]; do
        echo "Bootstrap verification attempt $((retries + 1))/$MAX_RETRIES"
        
        # Tester si talosctl get members fonctionne
        if talosctl --endpoints $BOOTSTRAP_NODE --nodes $BOOTSTRAP_NODE get members >/dev/null 2>&1; then
          MEMBER_COUNT=$(talosctl --endpoints $BOOTSTRAP_NODE --nodes $BOOTSTRAP_NODE get members 2>/dev/null | grep -c "cluster.*Member" || echo "0")
          echo "✅ Bootstrap successful - found $MEMBER_COUNT cluster members"
          exit 0
        fi
        
        retries=$((retries + 1))
        echo "⏳ Bootstrap not complete, waiting... (retry in $RETRY_DELAY s)"
        sleep $RETRY_DELAY
      done
      
      echo "❌ Bootstrap verification failed - bootstrap node not responding"
      exit 1
    EOT
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

# Enhanced API wait with better error handling
resource "null_resource" "wait_api" {
  depends_on = [null_resource.post_bootstrap_health_check]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"

      echo "Waiting for Kubernetes API server..."
      MAX_RETRIES=30
      RETRY_COUNT=0
      
      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if kubectl --kubeconfig="$TMP_KUBECONFIG" get --raw /version >/dev/null 2>&1; then
          echo "✅ API server is ready"
          rm -f "$TMP_KUBECONFIG"
          exit 0
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
          echo "⏳ API not ready, waiting... (attempt $RETRY_COUNT/$MAX_RETRIES)"
          sleep 10
        fi
      done
      
      echo "❌ API server failed to become ready"
      rm -f "$TMP_KUBECONFIG"
      exit 1
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

resource "null_resource" "post_deploy_checks" {
  depends_on = [null_resource.untaint_controlplanes]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.module}/scripts/post-deploy-checks.sh \"$KUBECONFIG_RAW\" 300"
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

resource "null_resource" "talos_api_check" {
  for_each = var.controlplane_config.nodes

  depends_on = [talos_machine_configuration_apply.controlplanes]

  triggers = {
    node_ip   = each.value.ip
    node_name = each.key
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      NODE_IP="${each.value.ip}"
      MAX_RETRIES=30
      RETRY_DELAY=10
      
      echo "Checking Talos API on node ${each.key} ($NODE_IP)..."
      
      # 1. Vérifier que le port 50000 est ouvert
      echo "⏳ Checking port 50000 on $NODE_IP..."
      retries=0
      while [ $retries -lt $MAX_RETRIES ]; do
        if timeout 5 bash -c "</dev/tcp/$NODE_IP/50000" 2>/dev/null; then
          echo "✅ Port 50000 reachable on $NODE_IP"
          break
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
          echo "⏳ Port 50000 not ready, waiting... (attempt $retries/$MAX_RETRIES)"
          sleep $RETRY_DELAY
        fi
      done
      
      if [ $retries -eq $MAX_RETRIES ]; then
        echo "❌ Port 50000 not reachable on $NODE_IP"
        exit 1
      fi
      
      # 2. Vérifier que Talos est prêt via dmesg
      echo "⏳ Checking Talos dmesg for readiness on $NODE_IP..."
      retries=0
      while [ $retries -lt $MAX_RETRIES ]; do
        # Utiliser talosctl avec les bons flags (sans --insecure)
        if timeout 30 talosctl --endpoints $NODE_IP --nodes $NODE_IP \
           --ca "${var.talos_certs.ca}" \
           --crt "${var.talos_certs.cert}" \
           --key "${var.talos_certs.key}" \
           dmesg 2>/dev/null | grep -Eq "bootstrap|first node|Talos initialized"; then
          echo "✅ Talos ready on $NODE_IP"
          exit 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
          echo "⏳ Talos not ready yet, waiting... (attempt $retries/$MAX_RETRIES)"
          sleep $RETRY_DELAY
        fi
      done
      
      echo "❌ Talos not ready on $NODE_IP after $MAX_RETRIES attempts"
      echo "Debug: Check node status and Talos logs"
      exit 1
    EOT
  }
}


resource "null_resource" "post_bootstrap_health_check" {
  depends_on = [null_resource.bootstrap_verification]

  triggers = {
    bootstrap_id = talos_machine_bootstrap.this.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e
      echo "Performing post-bootstrap health checks..."
      
      # Attendre que les nodes soient Ready
      TMP_KUBECONFIG=$(mktemp)
      echo "$KUBECONFIG_RAW" > "$TMP_KUBECONFIG"
      chmod 600 "$TMP_KUBECONFIG"
      
      echo "Waiting for nodes to be Ready..."
      kubectl --kubeconfig="$TMP_KUBECONFIG" wait --for=condition=ready nodes --all --timeout=300s
      
      echo "✅ Post-bootstrap health checks passed"
      rm -f "$TMP_KUBECONFIG"
    EOT
    environment = {
      KUBECONFIG_RAW = talos_cluster_kubeconfig.this.kubeconfig_raw
    }
  }
}

