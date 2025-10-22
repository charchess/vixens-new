import os

# Remplace le chemin par le chemin local vers ton dépôt
repo_path = '~/vixens-dev'

# Chemin du dossier Terraform
terraform_path = os.path.join(repo_path, 'terraform')

# Lister les fichiers dans le dossier Terraform
for root, dirs, files in os.walk(terraform_path):
    for file in files:
        file_path = os.path.join(root, file)
        print(f'Fichier: {file_path}')
        
        # Lire et afficher le contenu du fichier
        with open(file_path, 'r') as f:
            print(f.read())
            print('\n' + '-'*40 + '\n')  # Séparateur entre les fichiers