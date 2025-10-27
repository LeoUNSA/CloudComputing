#!/bin/bash

# Script para monitorear el autoscaling en tiempo real
# Muestra HPA, pods, nodos y métricas

set -e

NAMESPACE="${NAMESPACE:-todoapp}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-5}"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AutoScaling Monitor${NC}"
echo -e "${BLUE}  Presiona Ctrl+C para salir${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
sleep 2

while true; do
    clear
    
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     TodoApp AutoScaling Monitor       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}⏰ $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    
    # HPA Status
    echo -e "${YELLOW}━━━ Horizontal Pod Autoscalers ━━━${NC}"
    kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "No HPA found"
    echo ""
    
    # Pods Status
    echo -e "${YELLOW}━━━ Backend Pods ━━━${NC}"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=backend -o wide 2>/dev/null || echo "No backend pods found"
    echo ""
    
    echo -e "${YELLOW}━━━ Frontend Pods ━━━${NC}"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/component=frontend -o wide 2>/dev/null || echo "No frontend pods found"
    echo ""
    
    # Pod Metrics
    echo -e "${YELLOW}━━━ Pod Metrics (CPU/Memory) ━━━${NC}"
    kubectl top pods -n $NAMESPACE 2>/dev/null || echo "Metrics not available yet"
    echo ""
    
    # Node Status
    echo -e "${YELLOW}━━━ Cluster Nodes ━━━${NC}"
    kubectl get nodes -o wide 2>/dev/null || echo "Cannot get nodes"
    echo ""
    
    # Node Metrics
    echo -e "${YELLOW}━━━ Node Metrics (CPU/Memory) ━━━${NC}"
    kubectl top nodes 2>/dev/null || echo "Metrics not available yet"
    echo ""
    
    # Recent Events
    echo -e "${YELLOW}━━━ Recent Autoscaling Events ━━━${NC}"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' 2>/dev/null | grep -E 'HorizontalPodAutoscaler|Scaled' | tail -5 || echo "No recent scaling events"
    echo ""
    
    echo -e "${BLUE}Actualizando en ${REFRESH_INTERVAL} segundos...${NC}"
    sleep $REFRESH_INTERVAL
done
