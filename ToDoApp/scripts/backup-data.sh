#!/bin/bash

# Script para hacer backup de datos de PostgreSQL

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

# Verificar que el cluster esté corriendo
if ! kubectl get pods -n todoapp > /dev/null 2>&1; then
    print_error "Cluster no está disponible o no hay pods en namespace todoapp"
    exit 1
fi

# Crear directorio de backup si no existe
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"

# Nombre del archivo con timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/todoapp_backup_$TIMESTAMP.sql"

print_status "🗄️ Creando backup de PostgreSQL..."

# Exportar configuración de kubeconfig
export KUBECONFIG=/tmp/kubeconfig

# Hacer backup de la base de datos
kubectl exec deployment/todoapp-postgres -n todoapp -- pg_dump -U postgres -d tasksdb > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    print_status "✅ Backup creado exitosamente: $BACKUP_FILE"
    
    # Mostrar información del backup
    echo ""
    print_status "📊 Información del backup:"
    echo "  Archivo: $BACKUP_FILE"
    echo "  Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo "  Fecha: $(date)"
    
    # Mostrar las tareas que se respaldaron
    echo ""
    print_status "📝 Tareas respaldadas:"
    kubectl exec deployment/todoapp-postgres -n todoapp -- psql -U postgres -d tasksdb -c "SELECT COUNT(*) as total_tareas FROM tasks;"
    
else
    print_error "❌ Error al crear el backup"
    exit 1
fi

print_status "🔧 Para restaurar este backup, usa: ./scripts/restore-backup.sh $BACKUP_FILE"