📁 Structure du projet vixens-new
Ce dépôt organise l’infrastructure et les applications du projet Vixens autour de trois grands piliers : Kubernetes, Terraform, et scripts d’automatisation.
📂 docs/
Contient la documentation du projet.

    Sous-dossier adr/ : décisions d’architecture (ADR – Architecture Decision Records).

📂 kubernetes/
Définit l’état désiré du cluster Kubernetes (GitOps).

    apps/ : applications déployées dans les clusters.
    bootstrap/argocd/ : configuration initiale d’ArgoCD (outil GitOps).
    clusters/ : configuration spécifique par environnement.
        dev/, staging/, prod/ : overlays ou valeurs propres à chaque cluster.

📂 scripts/
Utilitaires et automatisations.

    environments/ : configurations locales par environnement (accès kube, talos).
        dev/ et prod/ : contiennent les fichiers de config pour chaque cible.

📂 terraform/
Infrastructure définie comme code (IaC).

    environments/ : déploiements Terraform par environnement.
        dev/, staging/, prod/ : états et variables spécifiques à chaque cible.
    modules/ : composants réutilisables Terraform (non environnement-spécifiques).
