#!/bin/bash

# Script para verificar el estado del deployment en GCP
# Usa curl y la API REST de GCP en lugar de gcloud CLI

PROJECT_ID="todoapp-autoscaling-demo"
CLUSTER_NAME="todoapp-autoscaling-cluster"
REGION="us-central1"
ZONE="us-central1-a"

echo "=== Estado del Deployment en GCP ==="
echo ""
echo "Proyecto: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
echo "Zona: $ZONE"
echo ""

# Obtener el token de acceso
echo "🔍 Obteniendo credenciales..."
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ No se pudo obtener el token de acceso"
    echo ""
    echo "Alternativa: Verifica en la consola web de GCP:"
    echo "https://console.cloud.google.com/kubernetes/list?project=$PROJECT_ID"
    exit 1
fi

echo "✅ Credenciales obtenidas"
echo ""

# Verificar clusters GKE
echo "🔍 Verificando clusters GKE..."
CLUSTERS=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://container.googleapis.com/v1/projects/$PROJECT_ID/locations/$ZONE/clusters" 2>/dev/null)

if echo "$CLUSTERS" | grep -q "\"name\": \"$CLUSTER_NAME\""; then
    echo "✅ Cluster '$CLUSTER_NAME' encontrado"
    
    # Extraer estado del cluster
    STATUS=$(echo "$CLUSTERS" | grep -A 2 "\"name\": \"$CLUSTER_NAME\"" | grep "status" | cut -d'"' -f4)
    echo "   Estado: $STATUS"
    
    # Contar nodos
    NODE_COUNT=$(echo "$CLUSTERS" | grep -o "\"currentNodeCount\": [0-9]*" | cut -d' ' -f2)
    if [ -n "$NODE_COUNT" ]; then
        echo "   Nodos actuales: $NODE_COUNT"
    fi
else
    echo "❌ Cluster '$CLUSTER_NAME' NO encontrado"
    echo ""
    echo "Posibles razones:"
    echo "  - El cluster aún se está creando"
    echo "  - Hubo un error en la creación"
    echo "  - El proyecto no tiene la API de GKE habilitada"
fi

echo ""
echo "=== Enlaces útiles ==="
echo "Console GKE: https://console.cloud.google.com/kubernetes/list?project=$PROJECT_ID"
echo "Compute Engine: https://console.cloud.google.com/compute/instances?project=$PROJECT_ID"
echo "Container Registry: https://console.cloud.google.com/gcr/images/$PROJECT_ID"
echo ""
