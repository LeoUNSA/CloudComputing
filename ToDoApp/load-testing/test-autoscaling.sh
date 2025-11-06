#!/bin/bash

# Script automatizado para probar autoscaling de pods y nodos
# Genera carga progresiva y monitorea el comportamiento del autoscaling

set -e

# Configuración
NAMESPACE="${NAMESPACE:-todoapp}"
SERVICE_NAME="${SERVICE_NAME:-todoapp-backend}"
LOAD_GENERATORS="${LOAD_GENERATORS:-8}"
STRESS_DURATION="${STRESS_DURATION:-30000}"
TEST_DURATION="${TEST_DURATION:-600}" # 10 minutos por defecto

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[i]${NC} $1"
}

# Banner
clear
print_header "AUTOSCALING TEST - PODS & NODES"
echo ""
print_info "Namespace: $NAMESPACE"
print_info "Service: $SERVICE_NAME"
print_info "Load generators: $LOAD_GENERATORS"
print_info "Test duration: $TEST_DURATION seconds"
echo ""

# Verificar que el cluster está accesible
print_status "Verificando acceso al cluster..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "No se puede acceder al cluster de Kubernetes"
    exit 1
fi

# Verificar que el namespace existe
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_error "El namespace '$NAMESPACE' no existe"
    exit 1
fi

# Mostrar estado inicial
print_header "ESTADO INICIAL"
echo ""
echo -e "${MAGENTA}📊 Pods actuales:${NC}"
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --no-headers | wc -l
echo ""
echo -e "${MAGENTA}🖥️  Nodos actuales:${NC}"
kubectl get nodes --no-headers | wc -l
echo ""
echo -e "${MAGENTA}📈 HPA Status:${NC}"
kubectl get hpa -n $NAMESPACE
echo ""

# Guardar estado inicial
INITIAL_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --no-headers | wc -l)
INITIAL_NODES=$(kubectl get nodes --no-headers | wc -l)

print_info "Estado inicial guardado: $INITIAL_PODS pods, $INITIAL_NODES nodos"
echo ""
read -p "Presiona ENTER para iniciar el test de carga..."
echo ""

# Crear generadores de carga
print_header "INICIANDO GENERADORES DE CARGA"
echo ""

print_status "Creando $LOAD_GENERATORS generadores de carga..."
for i in $(seq 1 $LOAD_GENERATORS); do
    kubectl run load-generator-$i \
        --image=busybox \
        --restart=Never \
        -n $NAMESPACE \
        --labels="role=load-generator" \
        -- /bin/sh -c "while true; do wget -q -O- http://$SERVICE_NAME:5001/stress?duration=$STRESS_DURATION 2>/dev/null; done" \
        2>/dev/null || true
    echo -e "${GREEN}  ✓${NC} Generador $i creado"
done

echo ""
print_status "Todos los generadores de carga están activos"
print_warning "Los pods empezarán a generar carga en unos segundos..."
echo ""

# Función para mostrar estadísticas
show_stats() {
    local timestamp=$(date +"%H:%M:%S")
    local pods=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --no-headers 2>/dev/null | wc -l)
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local pending_pods=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    
    # Obtener métricas de HPA
    local hpa_info=$(kubectl get hpa -n $NAMESPACE -o custom-columns=NAME:.metadata.name,CURRENT:.status.currentMetrics[0].resource.current.averageUtilization,TARGET:.spec.metrics[0].resource.target.averageUtilization,REPLICAS:.status.currentReplicas 2>/dev/null | tail -n +2)
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}⏰ $timestamp${NC}"
    echo -e "${MAGENTA}📊 Pods totales:${NC} $pods (Inicial: $INITIAL_PODS) | ${YELLOW}Pending:${NC} $pending_pods"
    echo -e "${MAGENTA}🖥️  Nodos:${NC} $nodes (Inicial: $INITIAL_NODES)"
    echo ""
    echo -e "${MAGENTA}📈 HPA Status:${NC}"
    echo "$hpa_info" | while read line; do
        echo "   $line"
    done
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Monitorear autoscaling
print_header "MONITOREANDO AUTOSCALING"
echo ""
print_info "Monitoreando por $TEST_DURATION segundos..."
print_info "Presiona Ctrl+C para detener el monitoreo anticipadamente"
echo ""

# Trap para limpiar al salir
cleanup() {
    echo ""
    print_warning "Deteniendo test..."
    stop_load_generators
    exit 0
}
trap cleanup INT TERM

# Monitorear durante el tiempo especificado
START_TIME=$(date +%s)
INTERVAL=10 # Actualizar cada 10 segundos

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED -ge $TEST_DURATION ]; then
        break
    fi
    
    show_stats
    
    REMAINING=$((TEST_DURATION - ELAPSED))
    print_info "Tiempo restante: $REMAINING segundos"
    
    sleep $INTERVAL
done

# Mostrar estadísticas finales
echo ""
print_header "ESTADÍSTICAS FINALES"
show_stats

FINAL_PODS=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=todoapp --no-headers | wc -l)
FINAL_NODES=$(kubectl get nodes --no-headers | wc -l)

echo ""
print_info "Cambios detectados:"
echo -e "  Pods: $INITIAL_PODS → $FINAL_PODS (${GREEN}+$((FINAL_PODS - INITIAL_PODS))${NC})"
echo -e "  Nodos: $INITIAL_NODES → $FINAL_NODES (${GREEN}+$((FINAL_NODES - INITIAL_NODES))${NC})"
echo ""

# Función para detener generadores
stop_load_generators() {
    print_header "LIMPIANDO GENERADORES DE CARGA"
    echo ""
    print_status "Eliminando generadores de carga..."
    kubectl delete pod -n $NAMESPACE -l role=load-generator --grace-period=0 --force 2>/dev/null || true
    echo ""
    print_status "Generadores eliminados"
    echo ""
    print_warning "Los pods y nodos comenzarán a reducirse gradualmente (5-10 minutos)"
    print_info "Puedes monitorear el scale-down con: watch -n 5 'kubectl get pods,nodes -n $NAMESPACE'"
}

# Preguntar si quiere detener la carga
echo ""
read -p "¿Detener los generadores de carga ahora? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    stop_load_generators
else
    print_warning "Los generadores seguirán activos. Para detenerlos manualmente:"
    print_info "kubectl delete pod -n $NAMESPACE -l role=load-generator"
fi

echo ""
print_header "TEST COMPLETADO"
echo ""
