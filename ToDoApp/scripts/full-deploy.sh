#!/bin/bash

# Script de despliegue completo con orden correcto

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_header "DESPLIEGUE COMPLETO TODOAPP"

# 1. Verificar Docker
print_status "Verificando Docker..."
if ! docker info &> /dev/null; then
    print_error "Docker no está corriendo. Iniciando Docker..."
    sudo systemctl start docker || {
        print_error "No se pudo iniciar Docker. Por favor inicia Docker manualmente y ejecuta de nuevo."
        exit 1
    }
    sleep 3
fi

# 2. Setup del cluster
print_header "1. CONFIGURACIÓN DEL CLUSTER"
./scripts/setup.sh

# 3. Desplegar aplicación SIN monitoreo
print_header "2. DESPLEGANDO APLICACIÓN"
print_status "Desplegando aplicación sin monitoreo..."

# Crear namespace si no existe
kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -

# Instalar aplicación con monitoreo deshabilitado
if helm list -n todoapp | grep -q "todoapp"; then
    print_status "Actualizando aplicación existente..."
    helm upgrade todoapp ./helm/todoapp -n todoapp --set monitoring.enabled=false
else
    print_status "Instalando nueva aplicación..."
    helm install todoapp ./helm/todoapp -n todoapp --set monitoring.enabled=false
fi

print_status "Esperando a que los pods estén listos..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=todoapp -n todoapp --timeout=300s

# 4. Instalar Prometheus
print_header "3. INSTALANDO PROMETHEUS"
./scripts/install-prometheus.sh

# 5. Actualizar aplicación CON monitoreo
print_header "4. HABILITANDO MONITOREO"
print_status "Actualizando aplicación para habilitar monitoreo..."
helm upgrade todoapp ./helm/todoapp -n todoapp --set monitoring.enabled=true --set monitoring.prometheus.enabled=true --set monitoring.prometheus.serviceMonitor.enabled=true

print_header "DESPLIEGUE COMPLETADO"

print_status "✅ Aplicación desplegada exitosamente!"

echo ""
print_status "📊 Estado de los recursos:"
kubectl get all -n todoapp

echo ""
print_status "🌐 URLs de acceso:"
echo "  Frontend: http://localhost:30000"
echo "  Backend API: http://localhost:30001"
echo "  Grafana: http://localhost:30002 (admin/admin123)"

echo ""
print_status "🔍 Para validar la instalación:"
echo "  ./scripts/validate.sh"