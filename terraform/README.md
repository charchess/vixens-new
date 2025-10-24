# Infrastructure as Code (Terraform)

Ce répertoire contient l'infrastructure Kubernetes définie en code pour le projet vixens-new.

## Structure

terraform/
├── README.md                 # Ce fichier
├── environments/             # Environnements (dev, staging, prod)
└── modules/                  # Modules Terraform réutilisables

## Environnements

- **[environments/dev](./environments/dev/)** : Environnement de développement entièrement configuré
- **[environments/staging](./environments/staging/)** : Environnement de staging (à configurer)
- **[environments/prod](./environments/prod/)** : Environnement de production (à configurer)

## Modules

- **[modules/argocd](./modules/argocd/)** : Module pour déployer ArgoCD via Helm

## Prérequis

- Terraform ≥ 1.0
- Accès au réseau 192.168.208.x pour les nœuds
- Certificats Talos configurés

## Utilisation rapide (environnement dev)

cd environments/dev/
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

Sécurité
⚠️ Important : Les fichiers terraform.tfvars contiennent des secrets et doivent être protégés :

chmod 600 environments/*/terraform.tfvars
