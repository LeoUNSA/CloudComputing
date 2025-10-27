#!/bin/bash

# Script para generar carga en el backend y demostrar autoscaling
# Este script usa Apache Bench (ab) para generar tráfico HTTP

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
NAMESPACE="${NAMESPACE:-todoapp}"
SERVICE_NAME="${SERVICE_NAME:-todoapp-backend}"
CONCURRENT_REQUESTS="${CONCURRENT_REQUESTS:-50}"
TOTAL_REQUESTS="${TOTAL_REQUESTS:-5000}"
DURATION="${DURATION:-300}" # 5 minutos

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  TodoApp AutoScaling Load Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar que kubectl está configurado
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl no está configurado correctamente${NC}"
    exit 1
fi

# Verificar que el namespace existe
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: El namespace '$NAMESPACE' no existe${NC}"
    exit 1
fi

# Obtener la IP del servicio
echo -e "${YELLOW}Obteniendo información del servicio...${NC}"
BACKEND_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$BACKEND_IP" ]; then
    echo -e "${YELLOW}LoadBalancer IP no disponible, intentando con ClusterIP...${NC}"
    BACKEND_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
fi

BACKEND_PORT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
BACKEND_URL="http://${BACKEND_IP}:${BACKEND_PORT}"

echo -e "${GREEN}Backend URL: ${BACKEND_URL}${NC}"
echo ""

# Función para mostrar estado de HPA
show_hpa_status() {
    echo -e "${BLUE}Estado actual de HPA:${NC}"
    kubectl get hpa -n $NAMESPACE
    echo ""
}

# Función para mostrar pods
show_pods_status() {
    echo -e "${BLUE}Pods actuales:${NC}"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=backend
    echo ""
}

# Función para mostrar métricas
show_metrics() {
    echo -e "${BLUE}Métricas de pods:${NC}"
    kubectl top pods -n $NAMESPACE -l app.kubernetes.io/component=backend
    echo ""
}

# Estado inicial
echo -e "${GREEN}=== Estado Inicial ===${NC}"
show_hpa_status
show_pods_status

echo -e "${YELLOW}Esperando 10 segundos antes de iniciar la carga...${NC}"
sleep 10

# Iniciar monitoreo en background
echo -e "${GREEN}Iniciando monitoreo en background...${NC}"
(
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  Monitoreo en Tiempo Real${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        date
        echo ""
        show_hpa_status
        show_pods_status
        show_metrics
        sleep 10
    done
) &
MONITOR_PID=$!

# Trap para limpiar el proceso de monitoreo
trap "kill $MONITOR_PID 2>/dev/null" EXIT

echo -e "${GREEN}=== Iniciando Prueba de Carga ===${NC}"
echo -e "Concurrencia: ${CONCURRENT_REQUESTS}"
echo -e "Total de requests: ${TOTAL_REQUESTS}"
echo ""

# Crear un pod temporal para generar carga desde dentro del cluster
kubectl run load-generator \
    --image=busybox \
    --restart=Never \
    --namespace=$NAMESPACE \
    --rm -i \
    --command -- /bin/sh -c \
    "while true; do wget -q -O- ${BACKEND_URL}/stress?duration=5000; done" &

LOAD_PID=$!

echo -e "${YELLOW}Generando carga durante ${DURATION} segundos...${NC}"
echo -e "${YELLOW}Presiona Ctrl+C para detener antes.${NC}"
echo ""

# Esperar la duración especificada
sleep $DURATION

# Detener generador de carga
kill $LOAD_PID 2>/dev/null || true
kubectl delete pod load-generator -n $NAMESPACE --ignore-not-found=true

echo -e "${GREEN}=== Carga detenida ===${NC}"
echo -e "${YELLOW}Esperando que el autoscaling se estabilice (3 minutos)...${NC}"
sleep 180

# Detener monitoreo
kill $MONITOR_PID 2>/dev/null || true

# Estado final
clear
echo -e "${GREEN}=== Estado Final ===${NC}"
show_hpa_status
show_pods_status
show_metrics

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Prueba de carga completada${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Para ver los logs de HPA:${NC}"
echo -e "kubectl describe hpa -n $NAMESPACE"
echo ""
echo -e "${YELLOW}Para ver eventos:${NC}"
echo -e "kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
