#!/bin/bash

# Script para parar la aplicación sin eliminar el cluster Kind (mantiene datos)

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "🔄 Parando aplicación (manteniendo cluster y datos)..."

# Exportar configuración de kubeconfig
export KUBECONFIG=/tmp/kubeconfig

# Hacer backup automático antes de parar
if kubectl get pods -n todoapp > /dev/null 2>&1; then
    print_status "💾 Creando backup automático antes de parar..."
    ./scripts/backup-data.sh
fi

# Desinstalar aplicación TodoApp (mantiene PVC)
if helm list -n todoapp | grep -q "todoapp"; then
    print_status "Parando TodoApp (manteniendo volúmenes)..."
    helm uninstall todoapp -n todoapp
fi

# Desinstalar Prometheus (opcional)
if helm list -n monitoring | grep -q "prometheus"; then
    print_status "Parando Prometheus..."
    helm uninstall prometheus -n monitoring
fi

print_status "✅ Aplicación parada"
print_warning "📊 Cluster Kind mantiene los datos en volúmenes persistentes"
print_status "🔄 Para reiniciar: make deploy (o make full-deploy para incluir Prometheus)"

echo ""
print_status "📋 Estado actual:"
kubectl get pv,pvc --all-namespaces 2>/dev/null | grep todoapp || echo "No hay volúmenes visibles (normal si se eliminaron namespaces)"