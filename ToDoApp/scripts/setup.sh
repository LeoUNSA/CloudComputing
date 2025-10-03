#!/bin/bash

# Script para configurar y desplegar TodoApp en Kubernetes con Kind

set -e

echo "🚀 Iniciando configuración de TodoApp en Kubernetes..."

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

# Verificar que Kind está instalado
if ! command -v kind &> /dev/null; then
    print_error "Kind no está instalado. Por favor instala Kind primero."
    echo "Instrucciones: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Verificar que Docker está corriendo
if ! docker info &> /dev/null; then
    print_error "Docker no está corriendo. Por favor inicia Docker primero."
    exit 1
fi

# Verificar que kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl no está instalado. Por favor instala kubectl primero."
    exit 1
fi

# Verificar que helm está instalado
if ! command -v helm &> /dev/null; then
    print_error "Helm no está instalado. Por favor instala Helm primero."
    echo "Instrucciones: https://helm.sh/docs/intro/install/"
    exit 1
fi

print_status "Todas las dependencias están instaladas ✓"

# Crear cluster de Kind si no existe
if ! kind get clusters | grep -q "todoapp-cluster"; then
    print_status "Creando cluster de Kind..."
    kind create cluster --config=k8s/kind-config.yaml
else
    print_status "Cluster todoapp-cluster ya existe"
fi

# Configurar kubectl para usar el cluster de Kind
kubectl cluster-info --context kind-todoapp-cluster

print_status "Construyendo imágenes Docker..."

# Construir imagen del backend
print_status "Construyendo imagen del backend..."
docker build -t todoapp-backend:latest ./backend

# Construir imagen del frontend
print_status "Construyendo imagen del frontend..."
docker build -t todoapp-frontend:latest ./frontend

# Cargar imágenes en Kind
print_status "Cargando imágenes en Kind..."
kind load docker-image todoapp-backend:latest --name todoapp-cluster
kind load docker-image todoapp-frontend:latest --name todoapp-cluster

print_status "Imágenes cargadas en Kind ✓"

echo ""
print_status "🎉 Configuración completada!"
echo ""
print_warning "Para desplegar la aplicación, ejecuta:"
echo "  ./scripts/deploy.sh"
echo ""
print_warning "Para instalar Prometheus, ejecuta:"
echo "  ./scripts/install-prometheus.sh"