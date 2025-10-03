#!/bin/bash

# Script para instalar Prometheus y Grafana

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

print_status "🔧 Instalando Prometheus y Grafana..."

# Crear namespace de monitoring
kubectl apply -f monitoring/prometheus-namespace.yaml

# Agregar repositorio de Helm para Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

print_status "Instalando kube-prometheus-stack..."

# Instalar o actualizar Prometheus stack
if helm list -n monitoring | grep -q "prometheus"; then
    print_status "Actualizando Prometheus stack existente..."
    helm upgrade prometheus prometheus-community/kube-prometheus-stack \
        -f monitoring/prometheus-values.yaml \
        -n monitoring
else
    print_status "Instalando nuevo Prometheus stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        -f monitoring/prometheus-values.yaml \
        -n monitoring
fi

print_status "Esperando a que Prometheus esté listo..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

print_status "✅ Prometheus y Grafana instalados exitosamente!"

echo ""
print_status "📊 Estado del monitoring:"
kubectl get all -n monitoring

echo ""
print_status "🌐 URLs de acceso:"
echo "  Grafana: http://localhost:30002 (admin/admin123)"
echo "  Prometheus: kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo "  AlertManager: kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring"

echo ""
print_status "🔍 Para acceder a Prometheus UI:"
echo "  kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
echo "  Luego visita: http://localhost:9090"

echo ""
print_status "📈 Grafana ya está configurado con dashboards predeterminados"
print_status "Credenciales de Grafana: admin / admin123"