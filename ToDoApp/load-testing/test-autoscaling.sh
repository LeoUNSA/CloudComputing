#!/bin/bash

# Script automatizado para probar autoscaling de pods y nodos
# Genera carga progresiva y monitorea el comportamiento del autoscaling

set -e

# Configuración
NAMESPACE="${NAMESPACE:-todoapp}"
BACKEND_SERVICE="${BACKEND_SERVICE:-todoapp-backend}"
FRONTEND_SERVICE="${FRONTEND_SERVICE:-todoapp-frontend}"
BACKEND_LABEL="${BACKEND_LABEL:-app.kubernetes.io/component=backend}"
FRONTEND_LABEL="${FRONTEND_LABEL:-app.kubernetes.io/component=frontend}"
LOAD_GENERATORS="${LOAD_GENERATORS:-15}"
BACKEND_GENERATORS="${BACKEND_GENERATORS:-8}"
FRONTEND_GENERATORS="${FRONTEND_GENERATORS:-7}"
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
print_info "Backend Service: $BACKEND_SERVICE"
print_info "Frontend Service: $FRONTEND_SERVICE"
print_info "Backend Load generators: $BACKEND_GENERATORS"
print_info "Frontend Load generators: $FRONTEND_GENERATORS"
print_info "Total Load generators: $((BACKEND_GENERATORS + FRONTEND_GENERATORS))"
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

# Verificar que el servicio backend existe
if ! kubectl get service $BACKEND_SERVICE -n $NAMESPACE &> /dev/null; then
    print_error "El servicio '$BACKEND_SERVICE' no existe en el namespace '$NAMESPACE'"
    print_info "Servicios disponibles:"
    kubectl get services -n $NAMESPACE
    exit 1
fi

# Verificar que el servicio frontend existe
if ! kubectl get service $FRONTEND_SERVICE -n $NAMESPACE &> /dev/null; then
    print_error "El servicio '$FRONTEND_SERVICE' no existe en el namespace '$NAMESPACE'"
    print_info "Servicios disponibles:"
    kubectl get services -n $NAMESPACE
    exit 1
fi

# Verificar que hay pods backend
BACKEND_PODS=$(kubectl get pods -n $NAMESPACE -l $BACKEND_LABEL --no-headers 2>/dev/null | wc -l)
if [ "$BACKEND_PODS" -eq 0 ]; then
    print_error "No se encontraron pods backend con el label '$BACKEND_LABEL'"
    print_info "Pods disponibles en el namespace:"
    kubectl get pods -n $NAMESPACE --show-labels
    exit 1
fi

# Verificar que hay pods frontend
FRONTEND_PODS=$(kubectl get pods -n $NAMESPACE -l $FRONTEND_LABEL --no-headers 2>/dev/null | wc -l)
if [ "$FRONTEND_PODS" -eq 0 ]; then
    print_error "No se encontraron pods frontend con el label '$FRONTEND_LABEL'"
    print_info "Pods disponibles en el namespace:"
    kubectl get pods -n $NAMESPACE --show-labels
    exit 1
fi

# Mostrar estado inicial
print_header "ESTADO INICIAL"
echo ""
echo -e "${MAGENTA}📊 Backend Pods:${NC}"
kubectl get pods -n $NAMESPACE -l $BACKEND_LABEL --no-headers 2>/dev/null | wc -l
echo ""
echo -e "${MAGENTA}🎨 Frontend Pods:${NC}"
kubectl get pods -n $NAMESPACE -l $FRONTEND_LABEL --no-headers 2>/dev/null | wc -l
echo ""
echo -e "${MAGENTA}🖥️  Nodos actuales:${NC}"
kubectl get nodes --no-headers 2>/dev/null | wc -l
echo ""
echo -e "${MAGENTA}📈 HPA Status:${NC}"
kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "No HPA found"
echo ""

# Guardar estado inicial
INITIAL_BACKEND_PODS=$(kubectl get pods -n $NAMESPACE -l $BACKEND_LABEL --no-headers 2>/dev/null | wc -l)
INITIAL_FRONTEND_PODS=$(kubectl get pods -n $NAMESPACE -l $FRONTEND_LABEL --no-headers 2>/dev/null | wc -l)
INITIAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

print_info "Estado inicial guardado: $INITIAL_BACKEND_PODS backend pods, $INITIAL_FRONTEND_PODS frontend pods, $INITIAL_NODES nodos"
echo ""
read -p "Presiona ENTER para iniciar el test de carga..."
echo ""

# Crear generadores de carga
print_header "INICIANDO GENERADORES DE CARGA"
echo ""

# Backend load generators
print_status "Creando $BACKEND_GENERATORS generadores de carga BACKEND..."
for i in $(seq 1 $BACKEND_GENERATORS); do
    # Eliminar generador anterior si existe
    kubectl delete pod backend-load-generator-$i -n $NAMESPACE --ignore-not-found=true --grace-period=0 --force &> /dev/null || true
    
    kubectl run backend-load-generator-$i \
        --image=busybox \
        --restart=Never \
        -n $NAMESPACE \
        --labels="role=load-generator,target=backend" \
        --command -- /bin/sh -c "while true; do wget -q -O- http://$BACKEND_SERVICE:5001/stress?duration=$STRESS_DURATION 2>/dev/null || sleep 1; done" \
        &> /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓${NC} Backend generador $i creado"
    else
        echo -e "${RED}  ✗${NC} Error creando backend generador $i"
    fi
    sleep 0.5
done

echo ""
# Frontend load generators
print_status "Creando $FRONTEND_GENERATORS generadores de carga FRONTEND..."
for i in $(seq 1 $FRONTEND_GENERATORS); do
    # Eliminar generador anterior si existe
    kubectl delete pod frontend-load-generator-$i -n $NAMESPACE --ignore-not-found=true --grace-period=0 --force &> /dev/null || true
    
    kubectl run frontend-load-generator-$i \
        --image=busybox \
        --restart=Never \
        -n $NAMESPACE \
        --labels="role=load-generator,target=frontend" \
        --command -- /bin/sh -c "while true; do wget -q -O- http://$FRONTEND_SERVICE:80/ 2>/dev/null || sleep 1; done" \
        &> /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}  ✓${NC} Frontend generador $i creado"
    else
        echo -e "${RED}  ✗${NC} Error creando frontend generador $i"
    fi
    sleep 0.5
done

echo ""
print_status "Todos los generadores de carga están activos"
print_warning "Los pods empezarán a generar carga en unos segundos..."
echo ""

# Función para mostrar estadísticas
show_stats() {
    local timestamp=$(date +"%H:%M:%S")
    local backend_pods=$(kubectl get pods -n $NAMESPACE -l $BACKEND_LABEL --no-headers 2>/dev/null | wc -l)
    local frontend_pods=$(kubectl get pods -n $NAMESPACE -l $FRONTEND_LABEL --no-headers 2>/dev/null | wc -l)
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    local pending_backend=$(kubectl get pods -n $NAMESPACE -l $BACKEND_LABEL --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    local pending_frontend=$(kubectl get pods -n $NAMESPACE -l $FRONTEND_LABEL --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
    
    # Obtener métricas de HPA de forma más robusta
    local hpa_output=$(kubectl get hpa -n $NAMESPACE 2>/dev/null)
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}⏰ $timestamp${NC}"
    echo -e "${MAGENTA}📊 Backend Pods:${NC} $backend_pods (Inicial: $INITIAL_BACKEND_PODS) | ${YELLOW}Pending:${NC} $pending_backend"
    echo -e "${MAGENTA}🎨 Frontend Pods:${NC} $frontend_pods (Inicial: $INITIAL_FRONTEND_PODS) | ${YELLOW}Pending:${NC} $pending_frontend"
    echo -e "${MAGENTA}🖥️  Nodos:${NC} $nodes (Inicial: $INITIAL_NODES)"
    echo ""
    if [ -n "$hpa_output" ]; then
        echo -e "${MAGENTA}📈 HPA Status:${NC}"
        echo "$hpa_output" | tail -n +2 | while read line; do
            echo "   $line"
        done
    else
        echo -e "${YELLOW}⚠ No HPA found${NC}"
    fi
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

FINAL_BACKEND_PODS=$(kubectl get pods -n $NAMESPACE -l $BACKEND_LABEL --no-headers 2>/dev/null | wc -l)
FINAL_FRONTEND_PODS=$(kubectl get pods -n $NAMESPACE -l $FRONTEND_LABEL --no-headers 2>/dev/null | wc -l)
FINAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

echo ""
print_info "Cambios detectados:"
echo -e "  Backend Pods: $INITIAL_BACKEND_PODS → $FINAL_BACKEND_PODS (${GREEN}+$((FINAL_BACKEND_PODS - INITIAL_BACKEND_PODS))${NC})"
echo -e "  Frontend Pods: $INITIAL_FRONTEND_PODS → $FINAL_FRONTEND_PODS (${GREEN}+$((FINAL_FRONTEND_PODS - INITIAL_FRONTEND_PODS))${NC})"
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
