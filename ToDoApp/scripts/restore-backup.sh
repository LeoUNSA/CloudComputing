#!/bin/bash

# Script para restaurar backup de PostgreSQL

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que se proporcione el archivo de backup
if [ $# -eq 0 ]; then
    print_error "Uso: $0 <archivo_backup.sql>"
    echo "Ejemplo: $0 ./backups/todoapp_backup_20251003_120000.sql"
    exit 1
fi

BACKUP_FILE="$1"

# Verificar que el archivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Archivo de backup no encontrado: $BACKUP_FILE"
    exit 1
fi

# Verificar que el cluster esté corriendo
if ! kubectl get pods -n todoapp > /dev/null 2>&1; then
    print_error "Cluster no está disponible o no hay pods en namespace todoapp"
    print_status "Ejecuta 'make full-deploy' primero"
    exit 1
fi

# Exportar configuración de kubeconfig
export KUBECONFIG=/tmp/kubeconfig

print_status "🔄 Restaurando backup desde: $BACKUP_FILE"

# Esperar que PostgreSQL esté listo
print_status "⏳ Esperando que PostgreSQL esté listo..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=postgres -n todoapp --timeout=60s

# Limpiar datos existentes (opcional, comentar si no quieres)
print_warning "🗑️ Eliminando datos existentes..."
kubectl exec deployment/todoapp-postgres -n todoapp -- psql -U postgres -d tasksdb -c "DELETE FROM tasks;"

# Restaurar el backup
print_status "📥 Restaurando datos desde backup..."
kubectl exec -i deployment/todoapp-postgres -n todoapp -- psql -U postgres -d tasksdb < "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    print_status "✅ Backup restaurado exitosamente"
    
    # Verificar datos restaurados
    echo ""
    print_status "📊 Verificando datos restaurados:"
    kubectl exec deployment/todoapp-postgres -n todoapp -- psql -U postgres -d tasksdb -c "SELECT COUNT(*) as total_tareas FROM tasks;"
    
    print_status "🎉 Los datos han sido restaurados. Puedes acceder a la aplicación en:"
    echo "  Frontend: http://localhost:30000"
    echo "  Backend: http://localhost:30001"
    
else
    print_error "❌ Error al restaurar el backup"
    exit 1
fi