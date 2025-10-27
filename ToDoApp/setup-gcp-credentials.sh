#!/bin/bash
# Script para configurar GCP service account y credenciales

set -e

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo "Error: No hay proyecto configurado en gcloud"
    exit 1
fi

echo "=== Configurando Service Account para proyecto: $PROJECT_ID ==="
echo ""

# Crear service account
echo "1. Creando service account..."
gcloud iam service-accounts create todoapp-deployer \
    --display-name="TodoApp Deployer" \
    --project=$PROJECT_ID 2>/dev/null || echo "  (ya existe, continuando...)"

echo ""
echo "2. Asignando roles..."

# Asignar roles necesarios
for role in roles/container.admin roles/compute.admin roles/storage.admin roles/iam.serviceAccountUser; do
    echo "  - $role"
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="$role" \
        --condition=None \
        >/dev/null 2>&1 || true
done

echo ""
echo "3. Creando credenciales..."
mkdir -p ~/.gcp
gcloud iam service-accounts keys create ~/.gcp/credentials.json \
    --iam-account=todoapp-deployer@${PROJECT_ID}.iam.gserviceaccount.com \
    --project=$PROJECT_ID 2>/dev/null || echo "  (usando credenciales existentes)"

echo ""
echo "4. Configurando variables de entorno..."
export GCP_PROJECT_ID=$PROJECT_ID
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"

# Determinar shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

# Agregar al archivo de configuración del shell
if ! grep -q "GCP_PROJECT_ID" $SHELL_RC 2>/dev/null; then
    echo "export GCP_PROJECT_ID=\"$PROJECT_ID\"" >> $SHELL_RC
    echo "export GCP_CREDENTIALS_FILE=\"\$HOME/.gcp/credentials.json\"" >> $SHELL_RC
    echo "  Variables agregadas a $SHELL_RC"
else
    echo "  Variables ya existen en $SHELL_RC"
fi

echo ""
echo "5. Habilitando APIs necesarias..."
for api in compute.googleapis.com container.googleapis.com containerregistry.googleapis.com; do
    echo "  - $api"
    gcloud services enable $api --project=$PROJECT_ID 2>/dev/null || true
done

echo ""
echo "=== ✓ Configuración Completada ==="
echo ""
echo "Variables configuradas:"
echo "  GCP_PROJECT_ID=$GCP_PROJECT_ID"
echo "  GCP_CREDENTIALS_FILE=$GCP_CREDENTIALS_FILE"
echo ""
echo "IMPORTANTE: Ejecuta esto en tu terminal actual:"
echo "  export GCP_PROJECT_ID=\"$PROJECT_ID\""
echo "  export GCP_CREDENTIALS_FILE=\"\$HOME/.gcp/credentials.json\""
echo ""
echo "O recarga tu shell:"
echo "  source $SHELL_RC"
