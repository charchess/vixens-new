locals {
  kubeconfig = yamldecode(var.kubeconfig_raw)
  server     = local.kubeconfig.clusters[0].cluster.server
  ca_crt     = local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  client_crt = local.kubeconfig.users[0].user["client-certificate-data"]
  client_key = local.kubeconfig.users[0].user["client-key-data"]

  default_values = {
    dex = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    controller = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    redis = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    repoServer = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    server = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    applicationSet = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    notifications = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
    redisSecretInit = {
      tolerations = [
        { key = "node-role.kubernetes.io/control-plane", operator = "Exists", effect = "NoSchedule" }
      ]
    }
  }

  final_values = try(yamlencode(merge(local.default_values, yamldecode(var.extra_values))), yamlencode(local.default_values))
}