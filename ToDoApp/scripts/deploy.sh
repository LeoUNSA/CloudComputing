#!/bin/bash

# Script para desplegar TodoApp usando Helm

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes coloreados
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "🚀 Desplegando TodoApp con Helm..."

# Crear namespace si no existe
kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -

# Instalar o actualizar la aplicación con Helm
if helm list -n todoapp | grep -q "todoapp"; then
    print_status "Actualizando aplicación existente..."
    helm upgrade todoapp ./helm/todoapp -n todoapp
else
    print_status "Instalando nueva aplicación..."
    helm install todoapp ./helm/todoapp -n todoapp
fi

print_status "Esperando a que los pods estén listos..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=todoapp -n todoapp --timeout=300s

print_status "✅ Aplicación desplegada exitosamente!"

echo ""
print_status "📊 Estado de los recursos:"
kubectl get all -n todoapp

echo ""
print_status "🌐 URLs de acceso:"
echo "  Frontend: http://localhost:30000"
echo "  Backend API: http://localhost:30001"

echo ""
print_status "🔍 Para ver los logs:"
echo "  Frontend: kubectl logs -l app.kubernetes.io/component=frontend -n todoapp"
echo "  Backend: kubectl logs -l app.kubernetes.io/component=backend -n todoapp"
echo "  Database: kubectl logs -l app.kubernetes.io/component=postgres -n todoapp"

echo ""
print_status "🗑️  Para eliminar la aplicación:"
echo "  helm uninstall todoapp -n todoapp"