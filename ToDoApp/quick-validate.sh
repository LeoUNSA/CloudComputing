#!/bin/bash
# Script simple de validación rápida

echo "=== Validación Rápida de Setup ==="
echo ""

# Función simple de check
check() {
    if command -v $1 &> /dev/null; then
        echo "✓ $1 instalado"
        return 0
    else
        echo "✗ $1 NO instalado"
        return 1
    fi
}

# Verificar herramientas
check python3
check ansible
check gcloud
check kubectl
check helm
check docker

echo ""
echo "=== Variables de Entorno ==="
echo "GCP_PROJECT_ID: ${GCP_PROJECT_ID:-NO CONFIGURADO}"
echo "GCP_CREDENTIALS_FILE: ${GCP_CREDENTIALS_FILE:-NO CONFIGURADO}"

echo ""
echo "=== Proyecto GCP ==="
gcloud config get-value project 2>/dev/null || echo "No configurado"

echo ""
echo "=== Docker ==="
docker ps &>/dev/null && echo "✓ Docker funcionando" || echo "✗ Docker no funciona (necesitas sudo?)"

echo ""
echo "=== Archivos ==="
test -f ~/.gcp/credentials.json && echo "✓ Credenciales existen" || echo "✗ Credenciales NO existen"

echo ""
echo "Listo!"
