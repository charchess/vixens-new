locals {
  kubeconfig = yamldecode(var.kubeconfig_raw)
  server     = local.kubeconfig.clusters[0].cluster.server
  ca_crt     = local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  client_crt = local.kubeconfig.users[0].user["client-certificate-data"]
  client_key = local.kubeconfig.users[0].user["client-key-data"]

  default_values = {
    ipam = { mode = "kubernetes" }
    kubeProxyReplacement = true
    k8sServiceHost = "localhost"
    k8sServicePort = 7445
    securityContext = {
      capabilities = {
        ciliumAgent = ["CHOWN","KILL","NET_ADMIN","NET_RAW","IPC_LOCK","SYS_ADMIN","SYS_RESOURCE","DAC_OVERRIDE","FOWNER","SETGID","SETUID"]
        cleanCiliumState = ["NET_ADMIN","SYS_ADMIN","SYS_RESOURCE"]
      }
    }
    cgroup = { autoMount = { enabled = false }, hostRoot = "/sys/fs/cgroup" }
  }

  final_values = try(yamlencode(merge(local.default_values, yamldecode(var.extra_values))), yamlencode(local.default_values))
}