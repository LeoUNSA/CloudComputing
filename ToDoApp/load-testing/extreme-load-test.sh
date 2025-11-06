#!/bin/bash

# Script para generar carga extrema y forzar escalado de nodos
# ADVERTENCIA: Esto generará costos en GCP

set -e

NAMESPACE="${NAMESPACE:-todoapp}"
SERVICE_NAME="${SERVICE_NAME:-todoapp-backend}"
PODS_COUNT="${PODS_COUNT:-40}"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}  ⚠️  EXTREME LOAD TEST ⚠️${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}Este test generará carga extrema que debería${NC}"
echo -e "${YELLOW}disparar tanto el autoscaling de pods como de nodos.${NC}"
echo ""
echo -e "${RED}ADVERTENCIA: Esto puede generar costos en GCP!${NC}"
echo ""
read -p "¿Deseas continuar? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo -e "${GREEN}Iniciando test extremo...${NC}"
echo -e "${GREEN}Se crearán $PODS_COUNT pods generadores de carga${NC}"
echo ""

# Crear múltiples pods generadores de carga
for i in $(seq 1 $PODS_COUNT); do
    echo -e "${YELLOW}Creando load-generator-$i...${NC}"
    
    kubectl run load-generator-$i \
        --image=busybox \
        --namespace=$NAMESPACE \
        --restart=Never \
        --command -- /bin/sh -c \
        "while true; do 
            for j in \$(seq 1 100); do 
                wget -q -O- http://${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:5000/stress?duration=30000 || true
            done
        done" &
    
    sleep 1
done

echo ""
echo -e "${GREEN}Todos los generadores de carga iniciados!${NC}"
echo ""
echo -e "${YELLOW}Monitorea el escalado con:${NC}"
echo -e "  watch -n 2 'kubectl get hpa,pods,nodes -n $NAMESPACE'"
echo ""
echo -e "${YELLOW}Para detener la carga:${NC}"
echo -e "  kubectl delete pods -n $NAMESPACE -l run=load-generator"
echo ""
echo -e "${RED}No olvides detener la carga cuando termines!${NC}"
