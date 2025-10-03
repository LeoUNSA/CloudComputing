#!/bin/bash

# Script de validación post-despliegue

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar pods
check_pods() {
    local namespace=$1
    local label=$2
    local description=$3
    
    echo -n "Verificando $description... "
    if kubectl get pods -l "$label" -n "$namespace" --no-headers 2>/dev/null | grep -q "Running"; then
        print_success "$description funcionando"
        return 0
    else
        print_error "$description no está funcionando"
        return 1
    fi
}

# Función para verificar servicios
check_service() {
    local namespace=$1
    local service=$2
    local port=$3
    local description=$4
    
    echo -n "Verificando $description... "
    if kubectl get service "$service" -n "$namespace" >/dev/null 2>&1; then
        print_success "Servicio $description encontrado"
        return 0
    else
        print_error "Servicio $description no encontrado"
        return 1
    fi
}

# Función para probar endpoint HTTP
test_endpoint() {
    local url=$1
    local description=$2
    local timeout=5
    
    echo -n "Probando $description ($url)... "
    if timeout $timeout curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
        print_success "$description responde correctamente"
        return 0
    else
        print_warning "$description no responde (puede que necesite más tiempo)"
        return 1
    fi
}

print_header "VALIDACIÓN DE TODOAPP EN KUBERNETES"

echo ""
print_info "Iniciando validación del despliegue..."
echo ""

# 1. Verificar herramientas
print_header "1. VERIFICACIÓN DE HERRAMIENTAS"

tools=("docker" "kind" "kubectl" "helm")
for tool in "${tools[@]}"; do
    if command_exists "$tool"; then
        print_success "$tool instalado"
    else
        print_error "$tool no encontrado"
        exit 1
    fi
done

# 2. Verificar cluster
print_header "2. VERIFICACIÓN DEL CLUSTER"

echo -n "Verificando conexión al cluster... "
if kubectl cluster-info --context kind-todoapp-cluster >/dev/null 2>&1; then
    print_success "Conectado al cluster kind-todoapp-cluster"
else
    print_error "No se puede conectar al cluster"
    exit 1
fi

echo -n "Verificando nodos... "
node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$node_count" -ge 1 ]; then
    print_success "$node_count nodo(s) disponible(s)"
else
    print_error "No hay nodos disponibles"
    exit 1
fi

# 3. Verificar namespaces
print_header "3. VERIFICACIÓN DE NAMESPACES"

namespaces=("todoapp")
for ns in "${namespaces[@]}"; do
    echo -n "Verificando namespace $ns... "
    if kubectl get namespace "$ns" >/dev/null 2>&1; then
        print_success "Namespace $ns existe"
    else
        print_warning "Namespace $ns no existe"
    fi
done

# 4. Verificar pods de la aplicación
print_header "4. VERIFICACIÓN DE PODS"

check_pods "todoapp" "app.kubernetes.io/component=postgres" "PostgreSQL"
check_pods "todoapp" "app.kubernetes.io/component=backend" "Backend API"
check_pods "todoapp" "app.kubernetes.io/component=frontend" "Frontend"

# 5. Verificar servicios
print_header "5. VERIFICACIÓN DE SERVICIOS"

check_service "todoapp" "todoapp-postgres" "5432" "PostgreSQL"
check_service "todoapp" "todoapp-backend" "5000" "Backend"
check_service "todoapp" "todoapp-frontend" "3000" "Frontend"

# 6. Verificar Helm releases
print_header "6. VERIFICACIÓN DE HELM"

echo -n "Verificando release de Helm... "
if helm list -n todoapp | grep -q "todoapp"; then
    print_success "Release todoapp encontrado"
    helm list -n todoapp
else
    print_warning "Release todoapp no encontrado"
fi

# 7. Verificar endpoints HTTP
print_header "7. VERIFICACIÓN DE ENDPOINTS"

sleep 5  # Esperar que los servicios estén completamente listos

test_endpoint "http://localhost:30000" "Frontend"
test_endpoint "http://localhost:30001/health" "Backend Health Check"

# 8. Verificar monitoreo (si está instalado)
print_header "8. VERIFICACIÓN DE MONITOREO"

if kubectl get namespace monitoring >/dev/null 2>&1; then
    print_info "Namespace monitoring encontrado"
    
    if kubectl get pods -l app.kubernetes.io/name=prometheus -n monitoring --no-headers 2>/dev/null | grep -q "Running"; then
        print_success "Prometheus funcionando"
    else
        print_warning "Prometheus no está funcionando"
    fi
    
    if kubectl get pods -l app.kubernetes.io/name=grafana -n monitoring --no-headers 2>/dev/null | grep -q "Running"; then
        print_success "Grafana funcionando"
        test_endpoint "http://localhost:30002" "Grafana"
    else
        print_warning "Grafana no está funcionando"
    fi
else
    print_info "Monitoreo no instalado (opcional)"
fi

# 9. Resumen de recursos
print_header "9. RESUMEN DE RECURSOS"

echo ""
print_info "Pods en namespace todoapp:"
kubectl get pods -n todoapp 2>/dev/null || echo "No se pueden obtener pods"

echo ""
print_info "Servicios en namespace todoapp:"
kubectl get services -n todoapp 2>/dev/null || echo "No se pueden obtener servicios"

# 10. URLs de acceso
print_header "10. URLS DE ACCESO"

echo ""
print_info "🌐 URLs disponibles:"
echo "  📱 Frontend: http://localhost:30000"
echo "  🔌 Backend API: http://localhost:30001"
echo "  🏥 Health Check: http://localhost:30001/health"

if kubectl get namespace monitoring >/dev/null 2>&1; then
    echo "  📊 Grafana: http://localhost:30002 (admin/admin123)"
fi

echo ""
print_info "🔧 Comandos útiles:"
echo "  make status              # Ver estado general"
echo "  make logs               # Ver logs de la aplicación"
echo "  make port-forward       # Port forwarding para desarrollo"
echo "  make test               # Probar endpoints"

echo ""
print_header "VALIDACIÓN COMPLETADA"

print_success "Validación terminada. Revisa los mensajes anteriores para cualquier problema."