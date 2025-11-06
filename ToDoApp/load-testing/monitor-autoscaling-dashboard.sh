#!/bin/bash

# Script interactivo para monitorear autoscaling en tiempo real
# Muestra pods, nodos y HPA en un dashboard visual

# Configuración
NAMESPACE="${NAMESPACE:-todoapp}"
REFRESH_INTERVAL="${REFRESH_INTERVAL:-3}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Función para obtener timestamp
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Función para dibujar el dashboard
draw_dashboard() {
    clear
    
    # Header
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                    AUTOSCALING MONITOR DASHBOARD                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}$(get_timestamp)${NC} | Namespace: ${YELLOW}$NAMESPACE${NC} | Refresh: ${YELLOW}${REFRESH_INTERVAL}s${NC}"
    echo ""
    
    # Pods section
    echo -e "${MAGENTA}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${WHITE} 📦 PODS STATUS                                                          ${MAGENTA}│${NC}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    
    local total_pods=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    local pending_pods=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    
    echo -e "  Total: ${WHITE}$total_pods${NC} | Running: ${GREEN}$running_pods${NC} | Pending: ${YELLOW}$pending_pods${NC}"
    echo ""
    
    # Lista de pods con estado
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp \
        -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,CPU:.status.containerStatuses[0].state 2>/dev/null | \
        head -20 | while read line; do
        if [[ $line == *"Running"* ]]; then
            echo -e "  ${GREEN}●${NC} $line"
        elif [[ $line == *"Pending"* ]]; then
            echo -e "  ${YELLOW}●${NC} $line"
        else
            echo -e "  ${WHITE}●${NC} $line"
        fi
    done
    
    echo ""
    
    # HPA section
    echo -e "${MAGENTA}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${WHITE} 📈 HORIZONTAL POD AUTOSCALER (HPA)                                      ${MAGENTA}│${NC}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    
    kubectl get hpa -n $NAMESPACE 2>/dev/null | tail -n +2 | while read name ref minpods maxpods replicas age; do
        echo -e "  ${CYAN}$name${NC}"
        echo -e "    Min/Max: ${YELLOW}$minpods${NC}/${YELLOW}$maxpods${NC} | Current: ${GREEN}$replicas${NC}"
    done
    
    echo ""
    
    # Métricas detalladas de HPA
    kubectl get hpa -n $NAMESPACE -o json 2>/dev/null | \
        jq -r '.items[] | 
            "  \(.metadata.name):\n" +
            "    CPU: \(.status.currentMetrics[0].resource.current.averageUtilization // "N/A")% / \(.spec.metrics[0].resource.target.averageUtilization)%\n" +
            "    Memory: \(.status.currentMetrics[1].resource.current.averageUtilization // "N/A")% / \(.spec.metrics[1].resource.target.averageUtilization // "N/A")%"' 2>/dev/null || echo "  (Métricas no disponibles)"
    
    echo ""
    
    # Nodes section
    echo -e "${MAGENTA}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${WHITE} 🖥️  CLUSTER NODES                                                        ${MAGENTA}│${NC}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    
    local total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo -e "  Total nodes: ${WHITE}$total_nodes${NC}"
    echo ""
    
    kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,ROLE:.metadata.labels.node-role\\.kubernetes\\.io/master,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory 2>/dev/null | \
        while read line; do
        if [[ $line == *"Ready"* ]]; then
            echo -e "  ${GREEN}●${NC} $line"
        else
            echo -e "  ${RED}●${NC} $line"
        fi
    done
    
    echo ""
    
    # Load generators section
    echo -e "${MAGENTA}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${WHITE} 🔥 LOAD GENERATORS                                                      ${MAGENTA}│${NC}"
    echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    
    local load_gen_count=$(kubectl get pods -n $NAMESPACE -l role=load-generator --no-headers 2>/dev/null | wc -l)
    if [ $load_gen_count -gt 0 ]; then
        echo -e "  ${RED}⚠${NC}  Active load generators: ${YELLOW}$load_gen_count${NC}"
        kubectl get pods -n $NAMESPACE -l role=load-generator --no-headers 2>/dev/null | head -5 | while read line; do
            echo -e "     ${YELLOW}▸${NC} $line"
        done
        if [ $load_gen_count -gt 5 ]; then
            echo -e "     ${YELLOW}...${NC} and $((load_gen_count - 5)) more"
        fi
    else
        echo -e "  ${GREEN}✓${NC} No active load generators"
    fi
    
    echo ""
    
    # Footer with controls
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE} Press Ctrl+C to exit | Refresh every ${REFRESH_INTERVAL}s                             ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Verificar que el cluster está accesible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}[✗]${NC} No se puede acceder al cluster de Kubernetes"
    exit 1
fi

# Verificar que el namespace existe
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}[✗]${NC} El namespace '$NAMESPACE' no existe"
    exit 1
fi

# Verificar que jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}[!]${NC} jq no está instalado. Algunas métricas no estarán disponibles."
    echo -e "${YELLOW}[!]${NC} Instalar: sudo pacman -S jq (Arch) o sudo apt install jq (Ubuntu)"
    echo ""
    read -p "Continuar de todas formas? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Mensaje inicial
clear
echo -e "${GREEN}[✓]${NC} Iniciando dashboard de monitoreo..."
echo -e "${GREEN}[✓]${NC} Namespace: $NAMESPACE"
echo -e "${GREEN}[✓]${NC} Intervalo de actualización: ${REFRESH_INTERVAL}s"
echo ""
sleep 2

# Loop principal
while true; do
    draw_dashboard
    sleep $REFRESH_INTERVAL
done
