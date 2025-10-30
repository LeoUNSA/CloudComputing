#!/bin/bash

# Script para verificar el estado de limpieza de recursos GCP

PROJECT_ID="todoapp-autoscaling-demo"

echo "=== Estado de Limpieza de Recursos GCP ==="
echo ""
echo "Proyecto: $PROJECT_ID"
echo ""

# Verificar cluster GKE
echo "🔍 Verificando cluster GKE..."
CLUSTER_STATUS=$(curl -s -H "Authorization: Bearer $(gcloud auth print-access-token 2>/dev/null)" \
  "https://container.googleapis.com/v1/projects/$PROJECT_ID/locations/us-central1-a/clusters/todoapp-autoscaling-cluster" 2>/dev/null | \
  python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('status', 'DELETED'))" 2>/dev/null)

if [ "$CLUSTER_STATUS" = "DELETED" ] || [ -z "$CLUSTER_STATUS" ]; then
    echo "   ✅ Cluster GKE: ELIMINADO"
else
    echo "   🔄 Cluster GKE: $CLUSTER_STATUS (eliminándose...)"
fi

# Verificar instancias de Compute Engine
echo ""
echo "🔍 Verificando instancias de Compute Engine..."
INSTANCES=$(gcloud compute instances list --project=$PROJECT_ID --format="value(name)" 2>/dev/null | wc -l)
if [ "$INSTANCES" -eq 0 ]; then
    echo "   ✅ Instancias: Ninguna activa"
else
    echo "   ⚠️  Instancias activas: $INSTANCES"
    gcloud compute instances list --project=$PROJECT_ID --format="table(name,zone,status)"
fi

# Verificar discos
echo ""
echo "🔍 Verificando discos persistentes..."
DISKS=$(gcloud compute disks list --project=$PROJECT_ID --format="value(name)" 2>/dev/null | wc -l)
echo "   Discos: $DISKS (se eliminarán con el cluster)"

# Verificar Load Balancers
echo ""
echo "🔍 Verificando Load Balancers..."
LBS=$(gcloud compute forwarding-rules list --project=$PROJECT_ID --format="value(name)" 2>/dev/null | wc -l)
if [ "$LBS" -eq 0 ]; then
    echo "   ✅ Load Balancers: Ninguno activo"
else
    echo "   ⚠️  Load Balancers activos: $LBS"
fi

echo ""
echo "=== Recursos que NO generan costo (se pueden mantener) ==="
echo "   • VPC Network (todoapp-network) - sin costo"
echo "   • Imágenes en GCR - costo mínimo de almacenamiento"
echo ""

echo "=== Resumen ==="
if [ "$CLUSTER_STATUS" = "DELETED" ] && [ "$INSTANCES" -eq 0 ]; then
    echo "✅ Todos los recursos costosos han sido eliminados"
    echo "💰 No se están generando costos significativos"
else
    echo "🔄 Aún hay recursos eliminándose..."
    echo "   Ejecuta este script nuevamente en unos minutos"
fi
echo ""
