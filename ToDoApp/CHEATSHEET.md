# 📝 Cheat Sheet - TodoApp GCP AutoScaling

## 🚀 Setup Inicial

### 1. Variables de Entorno
```bash
export GCP_PROJECT_ID="tu-proyecto-id"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"
```

### 2. Despliegue
```bash
# Opción 1: Usando Make
make validate
make deploy

# Opción 2: Usando Ansible directamente
cd ansible
./validate-setup.sh
ansible-playbook main.yml
```

## 📊 Monitoreo

### Ver Estado General
```bash
# Todas las métricas en una ventana
make monitor

# O manualmente:
cd load-testing
./monitor-autoscaling.sh
```

### HPAs
```bash
# Ver HPAs
kubectl get hpa -n todoapp

# Watch continuo
kubectl get hpa -n todoapp -w

# Detalles de HPA
kubectl describe hpa todoapp-backend -n todoapp
kubectl describe hpa todoapp-frontend -n todoapp

# Ver políticas de escalado
kubectl get hpa todoapp-backend -n todoapp -o yaml
```

### Pods
```bash
# Listar pods
kubectl get pods -n todoapp

# Con detalles de nodo
kubectl get pods -n todoapp -o wide

# Watch continuo
kubectl get pods -n todoapp -w

# Filtrar por componente
kubectl get pods -n todoapp -l app.kubernetes.io/component=backend
kubectl get pods -n todoapp -l app.kubernetes.io/component=frontend

# Ver logs
kubectl logs -f -n todoapp -l app.kubernetes.io/component=backend
make logs-backend
```

### Nodos
```bash
# Listar nodos
kubectl get nodes

# Con detalles
kubectl get nodes -o wide

# Ver recursos de nodos
kubectl describe nodes

# Watch continuo
kubectl get nodes -w
```

### Métricas
```bash
# Pods
kubectl top pods -n todoapp
make metrics-pods

# Nodos
kubectl top nodes
make metrics-nodes

# Por componente
kubectl top pods -n todoapp -l app.kubernetes.io/component=backend
```

### Eventos
```bash
# Eventos recientes
kubectl get events -n todoapp --sort-by='.lastTimestamp'

# Solo escalado
kubectl get events -n todoapp --sort-by='.lastTimestamp' | grep -i scale

# Watch continuo
kubectl get events -n todoapp -w

# Usando Make
make events
```

## 🧪 Pruebas de Carga

### Carga Básica
```bash
# Con Make
make load-test

# Directamente
cd load-testing
./simple-load-test.sh

# Personalizado
CONCURRENT_WORKERS=20 DURATION=300 ./simple-load-test.sh
```

### Carga Avanzada
```bash
make load-test-advanced

# O directamente
cd load-testing
./run-load-test.sh
```

### Carga Extrema (⚠️ Alto costo)
```bash
make load-test-extreme

# O directamente
cd load-testing
./extreme-load-test.sh
```

### Detener Carga
```bash
make stop-load

# O manualmente
kubectl delete pods -n todoapp -l run=load-generator
```

## 🔧 Operaciones

### Escalar Manualmente
```bash
# Backend
kubectl scale deployment todoapp-backend -n todoapp --replicas=5
make scale-backend REPLICAS=5

# Frontend
kubectl scale deployment todoapp-frontend -n todoapp --replicas=3
make scale-frontend REPLICAS=3

# Nota: HPA sobrescribirá el escalado manual
```

### Pausar AutoScaling
```bash
# Eliminar HPAs temporalmente
kubectl delete hpa todoapp-backend -n todoapp
kubectl delete hpa todoapp-frontend -n todoapp

# Re-aplicar con Helm
helm upgrade todoapp helm/todoapp -n todoapp -f values.yaml
```

### Restart Pods
```bash
# Backend
kubectl rollout restart deployment todoapp-backend -n todoapp

# Frontend
kubectl rollout restart deployment todoapp-frontend -n todoapp

# Ver estado del rollout
kubectl rollout status deployment todoapp-backend -n todoapp
```

### Shell en Pods
```bash
# Backend
make shell-backend
# O: kubectl exec -it -n todoapp <pod-name> -- /bin/sh

# Frontend
make shell-frontend
```

### Port Forward
```bash
# Frontend
make port-forward
# Accede en: http://localhost:3000

# Backend
kubectl port-forward -n todoapp svc/todoapp-backend 5000:5000
# Accede en: http://localhost:5000
```

## 🌐 Acceso a la Aplicación

### Obtener URL
```bash
make get-url

# O manualmente
kubectl get svc todoapp-frontend -n todoapp

# Obtener solo la IP
kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Endpoints
```bash
# Frontend
http://<EXTERNAL-IP>:3000

# Backend API
http://<EXTERNAL-IP>:5000

# Health Check
http://<EXTERNAL-IP>:5000/health

# Stress Test Endpoint
http://<EXTERNAL-IP>:5000/stress?duration=10000
```

## 📝 Logs y Debugging

### Ver Logs
```bash
# Backend - últimos 100 líneas
kubectl logs -n todoapp -l app.kubernetes.io/component=backend --tail=100

# Frontend - últimos 100 líneas
kubectl logs -n todoapp -l app.kubernetes.io/component=frontend --tail=100

# Seguir logs en tiempo real
kubectl logs -f -n todoapp -l app.kubernetes.io/component=backend

# Logs de un pod específico
kubectl logs -n todoapp <pod-name>

# Logs previos (si el pod crasheó)
kubectl logs -n todoapp <pod-name> --previous
```

### Describir Recursos
```bash
# Pods
kubectl describe pod <pod-name> -n todoapp

# Deployments
kubectl describe deployment todoapp-backend -n todoapp

# Services
kubectl describe svc todoapp-frontend -n todoapp

# HPAs
kubectl describe hpa -n todoapp
```

## 🔄 Actualizar Configuración

### Cambiar Thresholds de HPA
```bash
# Editar values.yaml
vim helm/todoapp/values.yaml

# Actualizar con Helm
helm upgrade todoapp helm/todoapp -n todoapp -f helm/todoapp/values.yaml
```

### Cambiar Recursos de Pods
```bash
# Editar values.yaml (sección resources)
vim helm/todoapp/values.yaml

# Aplicar cambios
helm upgrade todoapp helm/todoapp -n todoapp -f helm/todoapp/values.yaml
```

### Re-desplegar con Ansible
```bash
cd ansible
ansible-playbook deploy-app.yml
```

## 🧹 Limpieza

### Eliminar Todo
```bash
make destroy

# O con Ansible
cd ansible
ansible-playbook cleanup.yml
```

### Eliminar Solo la App
```bash
helm uninstall todoapp -n todoapp
kubectl delete namespace todoapp
```

### Verificar Limpieza
```bash
# Ver clusters
gcloud container clusters list --project=$GCP_PROJECT_ID

# Ver imágenes en GCR
gcloud container images list --repository=gcr.io/$GCP_PROJECT_ID

# Ver redes
gcloud compute networks list --project=$GCP_PROJECT_ID
```

## 🔍 Troubleshooting

### HPA muestra <unknown>
```bash
# Verificar metrics-server
kubectl get deployment metrics-server -n kube-system
kubectl logs -n kube-system -l k8s-app=metrics-server

# Reinstalar
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]="--kubelet-insecure-tls"

# Esperar 2 minutos y verificar
kubectl top pods -n todoapp
```

### Pods Pending
```bash
# Ver por qué está pending
kubectl describe pod <pod-name> -n todoapp

# Ver recursos de nodos
kubectl describe nodes | grep -A 5 "Allocated resources"

# Forzar escalado de nodos (debería ser automático)
# Verificar eventos del cluster autoscaler
kubectl logs -n kube-system -l k8s-app=cluster-autoscaler
```

### LoadBalancer Sin IP
```bash
# Esperar 2-3 minutos
# Si persiste, describir el servicio
kubectl describe svc todoapp-frontend -n todoapp

# Ver eventos
kubectl get events -n todoapp | grep -i loadbalancer
```

## 📊 Información Útil

### Ver Configuración Actual
```bash
# HPAs
kubectl get hpa -n todoapp -o yaml

# Deployments con réplicas
kubectl get deployments -n todoapp

# Resource requests y limits
kubectl get pods -n todoapp -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'
```

### Ver Cluster Autoscaler Config
```bash
gcloud container clusters describe todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --format="yaml(nodePools[].autoscaling)"
```

### Costos
```bash
make cost-estimate

# Ver uso actual de recursos
gcloud compute instances list --project=$GCP_PROJECT_ID
```

## 🎯 Escenarios Comunes

### Prueba Rápida (5 min)
```bash
# Terminal 1
make monitor

# Terminal 2
make load-test
```

### Prueba Completa (15 min)
```bash
# Terminal 1
cd load-testing && ./monitor-autoscaling.sh

# Terminal 2
DURATION=600 CONCURRENT_WORKERS=30 ./simple-load-test.sh
```

### Demo de Escalado de Nodos
```bash
# ⚠️ Generará costos
make load-test-extreme

# Observa:
# - HPAs escalan pods al máximo
# - Cluster Autoscaler añade nodos
# - Pods se distribuyen en nuevos nodos

# No olvides detener:
make stop-load
```

## 📚 Referencias Rápidas

### GCP Console
- Clusters: https://console.cloud.google.com/kubernetes/clusters
- Container Registry: https://console.cloud.google.com/gcr
- Compute Instances: https://console.cloud.google.com/compute/instances

### Comandos gcloud
```bash
# Ver proyecto actual
gcloud config get-value project

# Listar clusters
gcloud container clusters list

# Obtener credentials
gcloud container clusters get-credentials todoapp-autoscaling-cluster \
  --zone=us-central1-a

# Ver imágenes
gcloud container images list --repository=gcr.io/$GCP_PROJECT_ID
```

### Ansible
```bash
# Ver tags disponibles
ansible-playbook main.yml --list-tags

# Dry run
ansible-playbook main.yml --check

# Verbose
ansible-playbook main.yml -vv
```
