#!/usr/bin/env bash
# =============================================================================
# destroy.sh — Borra TODA la infraestructura de Azure para no gastar crédito
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

echo "⚠️  Esto borrará ACR, VM, AKS y todo lo creado por Terraform."
read -p "¿Continuar? (s/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
  echo "Cancelado."
  exit 0
fi

echo "🗑  Destruyendo recursos en Azure..."
terraform -chdir=terraform destroy -auto-approve

echo "✅ Todo destruido. No gastarás más crédito."