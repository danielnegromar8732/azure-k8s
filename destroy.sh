#!/usr/bin/env bash
# =============================================================================
# destroy.sh — Borra TODA la infraestructura de Azure para no gastar crédito
# =============================================================================
set -euo pipefail

cd "$(dirname "$0")"

echo "Destruyendo recursos en Azure..."
terraform -chdir=terraform destroy -auto-approve

echo "Todo destruido. No gastarás más crédito."
