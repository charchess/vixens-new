#!/bin/bash

# Vérifie si un argument a été passé
if [ -z "$1" ]; then
  echo "Usage: $0 <dossier>"
  exit 1
fi

# Dossier à explorer
folder="$1"

# Fonction pour lister les fichiers et leur contenu
list_files() {
  local current_folder="$1"
  
  # Lister les fichiers et sous-dossiers
  for entry in "$current_folder"/*; do
    if [ -d "$entry" ]; then
      echo "Dossier: $entry"
      list_files "$entry"  # Appel récursif pour les sous-dossiers
    elif [ -f "$entry" ]; then
      echo "Fichier: $entry"
      echo "Contenu:"
      cat "$entry" | sed 's/^/    /'  # Afficher le contenu avec indentation
      echo -e "\n"  # Ligne vide pour séparer les fichiers
    fi
  done
}

# Appel de la fonction avec le dossier principal
list_files "$folder"