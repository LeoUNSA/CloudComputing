#!/bin/bash

# Script para limpiar todos los recursos de Kubernetes

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

print_warning "⚠️  Este script eliminará TODOS los recursos de TodoApp y Prometheus"
read -p "¿Estás seguro? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operación cancelada"
    exit 0
fi

print_status "🧹 Limpiando recursos..."

# Desinstalar aplicación TodoApp
if helm list -n todoapp | grep -q "todoapp"; then
    print_status "Desinstalando TodoApp..."
    helm uninstall todoapp -n todoapp
fi

# Desinstalar Prometheus
if helm list -n monitoring | grep -q "prometheus"; then
    print_status "Desinstalando Prometheus..."
    helm uninstall prometheus -n monitoring
fi

# Eliminar namespaces
print_status "Eliminando namespaces..."
kubectl delete namespace todoapp --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true

# Eliminar cluster de Kind
print_status "Eliminando cluster de Kind..."
kind delete cluster --name todoapp-cluster

print_status "✅ Limpieza completada!"