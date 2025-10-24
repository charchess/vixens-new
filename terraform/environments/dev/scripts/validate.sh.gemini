#!/bin/bash
# CREATION: Script de validation
set -e

echo "🔍 Running Terraform validation..."

echo "📋 Formatting check..."
terraform fmt -check -recursive

echo "🔧 Configuration validation..."
terraform validate

echo "📊 Plan validation..."
terraform plan -out=tfplan

echo "✅ All validations passed!"

# Nettoyage
rm -f tfplan

