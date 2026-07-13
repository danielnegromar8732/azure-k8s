#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Despliega TODO el Caso Práctico 2 de UNIR con un solo comando
# =============================================================================
# Uso: ./deploy.sh
# Requisitos: az, terraform, podman, ansible, kubectl instalados y az login hecho
# =============================================================================
set -euo pipefail

# Colores para los mensajes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cd "$(dirname "$0")"

# =============================================================================
# 0) Verificaciones previas
# =============================================================================
info "Verificando herramientas..."
for cmd in az terraform podman ansible kubectl; do
  command -v "$cmd" >/dev/null || error "Falta: $cmd. Instálalo antes de continuar."
done
az account show >/dev/null 2>&1 || error "Ejecuta 'az login' primero."
info "✅ Todas las herramientas listas."

# =============================================================================
# 1) Infraestructura en Azure (Terraform)
# =============================================================================
info "Paso 1/6: Terraform — creando infraestructura (ACR + VM + AKS)..."
terraform -chdir=terraform init -input=false
terraform -chdir=terraform apply -auto-approve -input=false

# Leer outputs
ACR_LOGIN=$(terraform -chdir=terraform output -raw acr_login_server)
ACR_USER=$(terraform -chdir=terraform output -raw acr_admin_username)
ACR_PASS=$(terraform -chdir=terraform output -raw acr_admin_password)
VM_IP=$(terraform -chdir=terraform output -raw vm_public_ip)
AKS_RG=$(terraform -chdir=terraform output -raw aks_resource_group)
AKS_NAME=$(terraform -chdir=terraform output -raw aks_name)

info "✅ Infraestructura lista. ACR=$ACR_LOGIN | VM=$VM_IP"

# =============================================================================
# 2) Login al ACR con Podman
# =============================================================================
info "Paso 2/6: Login en ACR con Podman..."
podman login "$ACR_LOGIN" -u "$ACR_USER" -p "$ACR_PASS"
info "✅ Login ACR OK."

# =============================================================================
# 3) Build y push de las 2 imágenes (tag casopractico2, plataforma amd64)
# =============================================================================
info "Paso 3/6: Construyendo y subiendo imágenes al ACR..."

podman build --platform linux/amd64 \
  -t "$ACR_LOGIN/app-podman:casopractico2" \
  ./app-podman
podman push "$ACR_LOGIN/app-podman:casopractico2"

podman build --platform linux/amd64 \
  -t "$ACR_LOGIN/app-k8s:casopractico2" \
  ./app-k8s
podman push "$ACR_LOGIN/app-k8s:casopractico2"

info "✅ Imágenes subidas al ACR."

# =============================================================================
# 4) Generar inventario y variables de Ansible desde outputs de Terraform
# =============================================================================
info "Paso 4/6: Generando inventario de Ansible..."

mkdir -p ansible/group_vars

cat > ansible/inventory.ini <<EOF
[podman_vm]
$VM_IP ansible_user=azureuser ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

cat > ansible/group_vars/all.yml <<EOF
# Generado automáticamente por deploy.sh — NO editar a mano
acr_login_server: "$ACR_LOGIN"
acr_admin_username: "$ACR_USER"
acr_admin_password: "$ACR_PASS"
image_tag: "casopractico2"
EOF

info "✅ Inventario generado en ansible/inventory.ini"

# =============================================================================
# 5) Desplegar app en Podman (VM) con Ansible
# =============================================================================
info "Paso 5/6: Ansible — desplegando app Podman en la VM..."
ansible-galaxy collection install containers.podman kubernetes.core >/dev/null 2>&1 || true
pip install kubernetes >/dev/null 2>&1 || true

ansible-playbook -i ansible/inventory.ini ansible/playbook_podman.yml --private-key="$(pwd)/terraform/id_rsa"

info "✅ App Podman desplegada. URL: https://$VM_IP/"

# =============================================================================
# 6) Desplegar app en AKS con Ansible
# =============================================================================
info "Paso 6/6: Ansible — desplegando app K8s en AKS..."
az aks get-credentials --resource-group "$AKS_RG" --name "$AKS_NAME" --overwrite-existing

ansible-playbook -i ansible/inventory.ini ansible/playbook_k8s.yml -e "acr_login=$ACR_LOGIN"

# Esperar a que el Service tenga IP externa
info "Esperando IP pública del LoadBalancer de AKS (puede tardar 1-2 min)..."
for i in {1..30}; do
  K8S_IP=$(kubectl get svc contador-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$K8S_IP" ] && [ "$K8S_IP" != "<none>" ]; then
    break
  fi
  sleep 5
done

# =============================================================================
# 7) Resumen final
# =============================================================================
echo ""
echo "============================================================"
echo -e "${GREEN}🎉 DESPLIEGUE COMPLETADO${NC}"
echo "============================================================"
echo "📦 App Podman (VM):  https://$VM_IP/"
echo "   Usuario: alumno / Contraseña: unir2026"
echo "   (certificado autofirmado → acepta el aviso del navegador)"
echo ""
echo "📦 App K8s (AKS):    http://$K8S_IP/"
echo "   (contador persistente — prueba: borra el pod y recarga)"
echo "============================================================"
echo ""
echo "Para destruir todo: ./destroy.sh"
