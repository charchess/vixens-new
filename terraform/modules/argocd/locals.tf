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
      service = {
        type  = "NodePort"
        nodePort = 30080
      }
      config = {
        url = var.server_url != "" ? var.server_url : null   # null = auto
        "users.anonymous.enabled" = "true"
      }
      extraArgs = [
        "--insecure",
        "--address=0.0.0.0",
        "--disable-auth"
      ]
    }
    configs = {
      params = {
        "server.disable.auth"       = true
        "users.anonymous.enabled"   = true
      }
      rbac = {
        "policy.default" = "role:admin"
      }
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

locals {
  raw_template = file("${path.module}/templates/apps.yaml.tftpl")
  rendered     = templatestring(local.raw_template, var.app_of_apps_template_vars)
}