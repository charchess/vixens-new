
# Environnements Terraform

Ce répertoire contient les configurations Terraform pour différents environnements du cluster Kubernetes.

## Environnements disponibles

### 🟢 [dev](./dev/) - Environnement de développement
- **Statut** : ✅ Configuré et fonctionnel
- **Nœuds** : 3 controlplanes (obsy, onyx, opale)
- **CNI** : Cilium avec eBPF
- **GitOps** : ArgoCD
- **Documentation** : Voir [dev/README.md](./dev/README.md)

### 🟡 [staging](./staging/) - Environnement de staging
- **Statut** : ⚠️ Non configuré
- **Contenu** : Fichier `.gitkeep` uniquement
- **À faire** : Copier la structure de `dev/` et adapter les variables

### 🔴 [prod](./prod/) - Environnement de production
- **Statut** : ⚠️ Non configuré  
- **Contenu** : Fichier `.gitkeep` uniquement
- **À faire** : Copier la structure de `dev/` et adapter les variables

## Structure type d'un environnement

Chaque environnement devrait contenir :

environnement/
├── main.tf              # Configuration principale
├── variables.tf         # Définition des variables
├── terraform.tfvars     # Valeurs des variables (secrets)
├── README.md           # Documentation spécifique
├── controlplane.yaml   # Config Talos de base
├── cilium.yaml         # Manifeste CNI
├── cilium.yaml.tftpl   # Template Cilium
├── argocd.yaml         # Config ArgoCD
├── argocd.yaml.tftpl   # Template ArgoCD
├── vixens-*.yaml       # Patches par nœud
└── .gitkeep           # Pour git


## Créer un nouvel environnement
# Copier depuis dev
cp -r dev/ new-env/
cd new-env/

# Modifier les fichiers
# - terraform.tfvars (IPs, noms, secrets)
# - Patches nœuds (vixens-*.yaml)
# - Documentation (README.md)

Bonnes pratiques

    Sécurité : Protéger les fichiers .tfvars
    Naming : Préfixer les ressources par l'environnement
    Isolation : IPs et réseaux différents par environnement
    Documentation : Maintenir les README à jour