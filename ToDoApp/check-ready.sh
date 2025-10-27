#!/bin/bash
# Validación simplificada sin gcloud --version

echo "=== Validación Pre-Deployment ==="
echo ""

# Verificar herramientas básicas
echo "Verificando herramientas:"
command -v python3 >/dev/null 2>&1 && echo "✓ python3" || echo "✗ python3"
command -v ansible >/dev/null 2>&1 && echo "✓ ansible" || echo "✗ ansible"
command -v gcloud >/dev/null 2>&1 && echo "✓ gcloud" || echo "✗ gcloud"
command -v kubectl >/dev/null 2>&1 && echo "✓ kubectl" || echo "✗ kubectl"
command -v helm >/dev/null 2>&1 && echo "✓ helm" || echo "✗ helm"
command -v docker >/dev/null 2>&1 && echo "✓ docker" || echo "✗ docker"

echo ""
echo "Proyecto GCP actual:"
PROJECT=$(gcloud config get-value project 2>/dev/null)
echo "  $PROJECT"

echo ""
echo "Variables de entorno:"
echo "  GCP_PROJECT_ID=${GCP_PROJECT_ID:-❌ NO CONFIGURADO}"
echo "  GCP_CREDENTIALS_FILE=${GCP_CREDENTIALS_FILE:-❌ NO CONFIGURADO}"

echo ""
echo "Credenciales:"
if [ -f "$HOME/.gcp/credentials.json" ]; then
    echo "  ✓ Archivo existe: ~/.gcp/credentials.json"
else
    echo "  ✗ Archivo NO existe: ~/.gcp/credentials.json"
fi

echo ""
echo "Docker:"
if docker ps >/dev/null 2>&1; then
    echo "  ✓ Docker funciona correctamente"
else
    echo "  ✗ Docker necesita permisos o no está corriendo"
fi

echo ""
echo "=== Listo ==="
