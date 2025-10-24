# Module ArgoCD

Module Terraform pour déployer ArgoCD sur un cluster Kubernetes via Helm.

## Caractéristiques

- ✅ Installation via Helm chart officiel
- ✅ Support LoadBalancer avec IP statique
- ✅ Tolérances pour nœuds controlplane
- ✅ Namespace dédié (`argocd`)
- ✅ Timeout configurable (défaut: 600s)
- ✅ Attente du déploiement complet

## Utilisation

module "argocd" {
  source = "../../modules/argocd"
  
  # Requis
  kubeconfig_raw = talos_cluster_kubeconfig.this.kubeconfig_raw
  
  # Optionnel
  argocd_lb_ip   = "192.168.111.200"  # IP statique (vide = DHCP)
  chart_version  = "8.5.8"            # Version du chart
  namespace      = "argocd"           # Namespace cible
}

Variables
Table

Variable	Type	Défaut	Description
kubeconfig_raw	string	-	Kubeconfig brut (obligatoire)
argocd_lb_ip	string	""	IP statique pour LoadBalancer
chart_version	string	"8.5.8"	Version du chart Helm
namespace	string	"argocd"	Namespace de déploiement
Configuration appliquée
Service

    Type : LoadBalancer
    IP : Configurable via argocd_lb_ip

Tolérances
Le module applique des tolérances pour :

    node-role.kubernetes.io/control-plane:NoSchedule
    node.kubernetes.io/not-ready:NoSchedule

Ceci permet le scheduling sur les controlplanes.
Outputs
Aucun output défini actuellement.
Dépendances

    Provider helm ≥ 3.0
    Cluster Kubernetes fonctionnel
    Kubeconfig valide

Notes

    Le déploiement attend que tous les pods soient Ready
    Timeout de 10 minutes pour éviter les erreurs de délai
    Les tolérances permettent le déploiement sur controlplanes