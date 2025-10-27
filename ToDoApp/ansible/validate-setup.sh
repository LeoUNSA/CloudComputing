#!/bin/bash

# Script de validación para verificar que todo está configurado correctamente
# Ejecuta este script antes de hacer el deployment

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Pre-Deployment Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Función para check exitoso
check_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

# Función para check fallido
check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

# Función para warning
check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

echo -e "${BLUE}Verificando herramientas necesarias...${NC}"
echo ""

# Check ansible
if command -v ansible &> /dev/null; then
    VERSION=$(ansible --version | head -n1)
    check_ok "Ansible instalado: $VERSION"
else
    check_fail "Ansible no está instalado"
fi

# Check gcloud
if command -v gcloud &> /dev/null; then
    VERSION=$(gcloud version | grep "Google Cloud SDK" | head -n1)
    check_ok "Google Cloud SDK instalado: $VERSION"
else
    check_fail "Google Cloud SDK no está instalado"
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    VERSION=$(kubectl version --client --short 2>/dev/null)
    check_ok "kubectl instalado: $VERSION"
else
    check_fail "kubectl no está instalado"
fi

# Check helm
if command -v helm &> /dev/null; then
    VERSION=$(helm version --short)
    check_ok "Helm instalado: $VERSION"
else
    check_fail "Helm no está instalado"
fi

# Check docker
if command -v docker &> /dev/null; then
    VERSION=$(docker --version)
    check_ok "Docker instalado: $VERSION"
else
    check_warn "Docker no está instalado (necesario para build de imágenes)"
fi

echo ""
echo -e "${BLUE}Verificando variables de entorno...${NC}"
echo ""

# Check GCP_PROJECT_ID
if [ -z "$GCP_PROJECT_ID" ]; then
    check_fail "GCP_PROJECT_ID no está configurado"
    echo "   Ejecuta: export GCP_PROJECT_ID=\"tu-proyecto-id\""
else
    check_ok "GCP_PROJECT_ID: $GCP_PROJECT_ID"
fi

# Check GCP_CREDENTIALS_FILE
if [ -z "$GCP_CREDENTIALS_FILE" ]; then
    check_warn "GCP_CREDENTIALS_FILE no está configurado (usará default)"
    GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"
else
    check_ok "GCP_CREDENTIALS_FILE: $GCP_CREDENTIALS_FILE"
fi

# Verificar que el archivo existe
if [ -f "$GCP_CREDENTIALS_FILE" ]; then
    check_ok "Archivo de credenciales existe"
else
    check_fail "Archivo de credenciales no encontrado: $GCP_CREDENTIALS_FILE"
fi

echo ""
echo -e "${BLUE}Verificando configuración de GCP...${NC}"
echo ""

# Check gcloud auth
if gcloud auth list 2>/dev/null | grep -q "ACTIVE"; then
    ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    check_ok "gcloud autenticado: $ACCOUNT"
else
    check_fail "gcloud no está autenticado"
    echo "   Ejecuta: gcloud auth login"
fi

# Check gcloud project
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -n "$CURRENT_PROJECT" ]; then
    if [ "$CURRENT_PROJECT" == "$GCP_PROJECT_ID" ]; then
        check_ok "Proyecto configurado correctamente: $CURRENT_PROJECT"
    else
        check_warn "Proyecto actual ($CURRENT_PROJECT) difiere de GCP_PROJECT_ID ($GCP_PROJECT_ID)"
    fi
else
    check_fail "No hay proyecto configurado en gcloud"
fi

# Check APIs habilitadas
echo ""
echo -e "${BLUE}Verificando APIs de GCP (puede tomar unos segundos)...${NC}"
echo ""

if [ -n "$GCP_PROJECT_ID" ]; then
    # Check Compute Engine API
    if gcloud services list --enabled --project="$GCP_PROJECT_ID" 2>/dev/null | grep -q "compute.googleapis.com"; then
        check_ok "Compute Engine API habilitada"
    else
        check_warn "Compute Engine API no habilitada (se habilitará durante deployment)"
    fi
    
    # Check Container API
    if gcloud services list --enabled --project="$GCP_PROJECT_ID" 2>/dev/null | grep -q "container.googleapis.com"; then
        check_ok "Kubernetes Engine API habilitada"
    else
        check_warn "Kubernetes Engine API no habilitada (se habilitará durante deployment)"
    fi
    
    # Check Container Registry API
    if gcloud services list --enabled --project="$GCP_PROJECT_ID" 2>/dev/null | grep -q "containerregistry.googleapis.com"; then
        check_ok "Container Registry API habilitada"
    else
        check_warn "Container Registry API no habilitada (se habilitará durante deployment)"
    fi
fi

echo ""
echo -e "${BLUE}Verificando archivos del proyecto...${NC}"
echo ""

# Check estructura de directorios
REQUIRED_DIRS=(
    "ansible"
    "ansible/inventories/gcp"
    "helm/todoapp"
    "load-testing"
    "backend"
    "frontend"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        check_ok "Directorio existe: $dir"
    else
        check_fail "Directorio faltante: $dir"
    fi
done

# Check archivos críticos
REQUIRED_FILES=(
    "ansible/main.yml"
    "ansible/setup-gke-cluster.yml"
    "ansible/inventories/gcp/group_vars/all.yml"
    "helm/todoapp/values.yaml"
    "helm/todoapp/Chart.yaml"
    "backend/Dockerfile"
    "frontend/Dockerfile"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_ok "Archivo existe: $file"
    else
        check_fail "Archivo faltante: $file"
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Resumen de Validación${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Todas las validaciones pasaron!${NC}"
    echo -e "${GREEN}Puedes proceder con el deployment.${NC}"
    echo ""
    echo -e "Siguiente paso:"
    echo -e "  ${BLUE}cd ansible && ansible-playbook main.yml${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validación completada con $WARNINGS advertencias${NC}"
    echo -e "${YELLOW}Puedes proceder, pero revisa las advertencias.${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Validación falló con $ERRORS errores y $WARNINGS advertencias${NC}"
    echo -e "${RED}Corrige los errores antes de proceder.${NC}"
    echo ""
    exit 1
fi
