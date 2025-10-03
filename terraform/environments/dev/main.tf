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

resource "talos_machine_bootstrap" "this" {
  node = values(var.controlplanes)[0].ip

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }

  depends_on = [talos_machine_configuration_apply.controlplanes]
}

resource "talos_cluster_kubeconfig" "this" {
  node = values(var.controlplanes)[0].ip

  client_configuration = {
    endpoint           = var.cluster_endpoint
    ca_certificate     = var.talos_certs.ca
    client_certificate = var.talos_certs.cert
    client_key         = var.talos_certs.key
  }

  depends_on = [talos_machine_bootstrap.this]
}

resource "helm_release" "cilium" {
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
    { name = "operator.replicas",    value = "1" }
  ]


  depends_on = [talos_cluster_kubeconfig.this]
}




output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
