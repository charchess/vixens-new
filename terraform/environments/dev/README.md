# Terraform / Talos - déploiement vixens-dev (controlplanes)

Emplacement projet:
`~/vixens-new/terraform/environments/dev/`

Fichiers:
- main.tf
- variables.tf
- terraform.tfvars
- controlplane.yaml (référence en `terraform.tfvars`)
- vixens-obsy.yaml, vixens-onyx.yaml, vixens-dev-opale.yaml (patches machines)

## Prérequis
- Terraform (compatible with provider requirements)
- Node(s) Talos en mode maintenance, accessibles aux IPs indiquées:
  - obsy -> 192.168.208.162
  - onyx -> 192.168.208.164
  - opale -> 192.168.208.163
- Le fichier `controlplane.yaml` (généré par `talosctl gen config`) à l'emplacement indiqué
- Les patch files (vixens-*.yaml) à l'emplacement indiqué
- Talos client certs (déjà placés dans terraform.tfvars)

## Commandes
```bash
cd ~/vixens-new/terraform/environments/dev

# (protéger le fichier de vars)
chmod 600 terraform.tfvars

terraform init
terraform validate
terraform plan -var-file=terraform.tfvars

# si plan OK
terraform apply -var-file=terraform.tfvars

