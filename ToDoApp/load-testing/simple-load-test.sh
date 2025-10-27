#!/bin/bash

# Script simple para generar carga continua usando curl
# Útil cuando no se tiene Apache Bench disponible

set -e

# Configuración
NAMESPACE="${NAMESPACE:-todoapp}"
SERVICE_NAME="${SERVICE_NAME:-todoapp-backend}"
CONCURRENT_WORKERS="${CONCURRENT_WORKERS:-10}"
DURATION="${DURATION:-300}" # 5 minutos
STRESS_DURATION="${STRESS_DURATION:-10000}" # 10 segundos por request

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Simple Load Test with curl${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Obtener la IP del servicio
BACKEND_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$BACKEND_IP" ]; then
    BACKEND_IP=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
fi
BACKEND_PORT=$(kubectl get svc $SERVICE_NAME -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}')
BACKEND_URL="http://${BACKEND_IP}:${BACKEND_PORT}"

echo -e "${GREEN}Target: ${BACKEND_URL}${NC}"
echo -e "${GREEN}Workers: ${CONCURRENT_WORKERS}${NC}"
echo -e "${GREEN}Duration: ${DURATION} seconds${NC}"
echo ""

# Función para generar carga
generate_load() {
    local worker_id=$1
    local end_time=$(($(date +%s) + DURATION))
    
    while [ $(date +%s) -lt $end_time ]; do
        curl -s "${BACKEND_URL}/stress?duration=${STRESS_DURATION}" > /dev/null
        echo "Worker $worker_id: request completed"
    done
}

# Iniciar workers en background
echo -e "${YELLOW}Iniciando $CONCURRENT_WORKERS workers...${NC}"
for i in $(seq 1 $CONCURRENT_WORKERS); do
    generate_load $i &
done

echo -e "${GREEN}Carga iniciada. Esperando $DURATION segundos...${NC}"
echo -e "${YELLOW}Monitorea con: kubectl get hpa -n $NAMESPACE -w${NC}"
echo ""

# Esperar a que todos los workers terminen
wait

echo -e "${GREEN}Carga completada!${NC}"
