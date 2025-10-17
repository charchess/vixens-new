resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  #  version          = "8.5.8"
  timeout = 600  # 10 min au lieu de ~5 min par défaut
  wait    = true # attendre réellement les replicas Ready

  set = [
    {
      name  = "server.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "server.service.loadBalancerIP"
      value = var.argocd_lb_ip
    },
    # tolérances pour que le Job redis-secret-init schedule tout de suite
    {
      name  = "redisSecretInit.tolerations[0].key"
      value = "node-role.kubernetes.io/control-plane"
    },
    {
      name  = "redisSecretInit.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "redisSecretInit.tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "redisSecretInit.tolerations[1].key"
      value = "node.kubernetes.io/not-ready"
    },
    {
      name  = "redisSecretInit.tolerations[1].operator"
      value = "Exists"
    },
    {
      name  = "redisSecretInit.tolerations[1].effect"
      value = "NoSchedule"
    },
    # on laisse aussi les tolerances habituelles au besoin
    {
      name  = "server.tolerations[0].key"
      value = "node-role.kubernetes.io/control-plane"
    },
    {
      name  = "server.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "server.tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "repoServer.tolerations[0].key"
      value = "node-role.kubernetes.io/control-plane"
    },
    {
      name  = "repoServer.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "repoServer.tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "applicationSet.tolerations[0].key"
      value = "node-role.kubernetes.io/control-plane"
    },
    {
      name  = "applicationSet.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "applicationSet.tolerations[0].effect"
      value = "NoSchedule"
    },
    {
      name  = "notifications.tolerations[0].key"
      value = "node-role.kubernetes.io/control-plane"
    },
    {
      name  = "notifications.tolerations[0].operator"
      value = "Exists"
    },
    {
      name  = "notifications.tolerations[0].effect"
      value = "NoSchedule"
    }
  ]
}