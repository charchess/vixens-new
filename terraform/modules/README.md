# Modules Terraform

Modules réutilisables pour l'infrastructure vixens-new.

## Modules disponibles

### 📦 [argocd](./argocd/) - Module ArgoCD
Déploiement d'ArgoCD via Helm chart avec configuration personnalisée.

**Caractéristiques :**
- Installation via Helm chart officiel
- Support LoadBalancer avec IP statique
- Tolérances pour controlplanes
- Namespace dédié
- Timeout configurable

**Utilisation :**
module "argocd" {
  source = "../../modules/argocd"
  
  kubeconfig_raw = talos_cluster_kubeconfig.this.kubeconfig_raw
  argocd_lb_ip   = "192.168.111.200"
}

Structure d'un module

module/
├── main.tf      # Ressources principales
├── variables.tf # Variables d'entrée
├── outputs.tf   # Sorties (si nécessaire)
└── README.md    # Documentation du module

Créer un nouveau module

    Créer un dossier pour le module
    Implémenter main.tf avec les ressources
    Définir les variables dans variables.tf
    Documenter dans README.md
    Ajouter des exemples d'utilisation

Bonnes pratiques

    Nommage : Préfixer les ressources par le nom du module
    Variables : Rendre les modules paramétrables
    Validation : Ajouter des validations de variables
    Documentation : Documenter chaque variable et sortie
    Tests : Tester le module dans un environnement isolé