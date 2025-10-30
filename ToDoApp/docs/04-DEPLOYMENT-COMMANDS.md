# Comandos de Despliegue y Gestión

## Índice
1. [Prerequisitos](#prerequisitos)
2. [Configuración Inicial](#configuración-inicial)
3. [Despliegue Completo](#despliegue-completo)
4. [Verificación y Monitoreo](#verificación-y-monitoreo)
5. [Gestión del Cluster](#gestión-del-cluster)
6. [Troubleshooting](#troubleshooting)
7. [Limpieza de Recursos](#limpieza-de-recursos)

---

## Prerequisitos

### Software Requerido

```bash
# Verificar instalaciones
gcloud --version       # Google Cloud SDK
kubectl version        # Kubernetes CLI
helm version           # Helm package manager
docker --version       # Docker Engine
ansible --version      # Ansible (>= 2.9)
```

### Instalación en Arch Linux

```bash
# Instalar todas las dependencias
sudo pacman -S google-cloud-sdk kubectl helm docker ansible

# Iniciar servicio Docker
sudo systemctl start docker
sudo systemctl enable docker

# Añadir usuario al grupo docker
sudo usermod -aG docker $USER
newgrp docker  # O logout/login
```

### Instalación en Ubuntu/Debian

```bash
# Google Cloud SDK
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt update && sudo apt install google-cloud-sdk

# kubectl
sudo apt install kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Docker
sudo apt install docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Ansible
sudo apt install ansible
```

---

## Configuración Inicial

### 1. Autenticación en GCP

```bash
# Login con cuenta de usuario
gcloud auth login
# Se abrirá navegador para autenticación

# Verificar autenticación
gcloud auth list

# Salida esperada:
#        Credentialed Accounts
# ACTIVE  ACCOUNT
# *       lmontoyac@unsa.edu.pe
```

### 2. Configurar Proyecto GCP

```bash
# Crear proyecto (si no existe)
gcloud projects create todoapp-autoscaling-demo \
  --name="TodoApp AutoScaling Demo"

# Establecer proyecto por defecto
gcloud config set project todoapp-autoscaling-demo

# Verificar proyecto activo
gcloud config get-value project
```

### 3. Vincular Cuenta de Billing

```bash
# Listar billing accounts disponibles
gcloud billing accounts list

# Vincular billing account al proyecto
gcloud billing projects link todoapp-autoscaling-demo \
  --billing-account=XXXXXX-XXXXXX-XXXXXX

# Verificar billing habilitado
gcloud billing projects describe todoapp-autoscaling-demo
# Debe mostrar: billingEnabled: true
```

### 4. Configurar Región y Zona

```bash
# Establecer región/zona por defecto
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Verificar configuración
gcloud config list
```

### 5. Deshabilitar Checks Innecesarios (Arch Linux)

```bash
# Evitar hangs de gcloud CLI
gcloud config set component_manager/disable_update_check true
gcloud config set disable_usage_reporting true
```

---

## Despliegue Completo

### Opción 1: Despliegue Automatizado con Ansible (Recomendado)

```bash
# 1. Navegar al directorio del proyecto
cd /home/leo/CloudComputing/ToDoApp

# 2. Verificar variables de configuración
cat ansible/inventories/gcp/group_vars/all.yml

# 3. Ejecutar playbook completo
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml

# Salida esperada:
# PLAY RECAP ********************************************************
# 127.0.0.1 : ok=XX changed=XX unreachable=0 failed=0

# Duración aproximada: 10-16 minutos
```

### Opción 2: Despliegue Por Fases (Ansible con Tags)

```bash
# Fase 1: Solo crear cluster GKE
ansible-playbook -i ansible/inventories/gcp/hosts.yml \
  ansible/main.yml --tags cluster

# Fase 2: Solo build y push de imágenes
ansible-playbook -i ansible/inventories/gcp/hosts.yml \
  ansible/main.yml --tags build,images

# Fase 3: Solo desplegar aplicación
ansible-playbook -i ansible/inventories/gcp/hosts.yml \
  ansible/main.yml --tags deploy,app
```

### Opción 3: Despliegue Manual (Paso a Paso)

#### Paso 1: Habilitar APIs

```bash
# Habilitar APIs necesarias
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com

# Verificar APIs habilitadas
gcloud services list --enabled
```

#### Paso 2: Crear Red VPC

```bash
# Crear VPC network
gcloud compute networks create todoapp-network \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

# Crear subnet
gcloud compute networks subnets create todoapp-subnet \
  --network=todoapp-network \
  --range=10.0.0.0/24 \
  --region=us-central1

# Verificar creación
gcloud compute networks list
gcloud compute networks subnets list
```

#### Paso 3: Crear Cluster GKE

```bash
# Crear cluster con autoscaling
gcloud container clusters create todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --network=todoapp-network \
  --subnetwork=todoapp-subnet \
  --machine-type=e2-standard-2 \
  --num-nodes=2 \
  --min-nodes=2 \
  --max-nodes=10 \
  --enable-autoscaling \
  --enable-autorepair \
  --enable-autoupgrade \
  --addons=HorizontalPodAutoscaling \
  --disk-size=50 \
  --disk-type=pd-standard

# Duración: 5-8 minutos

# Verificar cluster
gcloud container clusters list
```

#### Paso 4: Obtener Credenciales kubectl

```bash
# Configurar kubectl
gcloud container clusters get-credentials todoapp-autoscaling-cluster \
  --zone=us-central1-a

# Verificar conectividad
kubectl cluster-info
kubectl get nodes
```

#### Paso 5: Crear Namespace

```bash
# Crear namespace todoapp
kubectl create namespace todoapp

# Verificar
kubectl get namespaces
```

#### Paso 6: Build y Push de Imágenes Docker

```bash
# Configurar Docker para GCR
gcloud auth configure-docker

# Build imagen backend
docker build -t gcr.io/todoapp-autoscaling-demo/todoapp-backend:latest \
  -f backend/Dockerfile backend/

# Build imagen frontend
docker build -t gcr.io/todoapp-autoscaling-demo/todoapp-frontend:latest \
  -f frontend/Dockerfile frontend/

# Push a GCR
docker push gcr.io/todoapp-autoscaling-demo/todoapp-backend:latest
docker push gcr.io/todoapp-autoscaling-demo/todoapp-frontend:latest

# Verificar imágenes en GCR
gcloud container images list
```

#### Paso 7: Desplegar con Helm

```bash
# Agregar repo metrics-server (si no existe)
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Instalar metrics-server
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}

# Desplegar TodoApp
helm upgrade --install todoapp helm/todoapp \
  --namespace todoapp \
  --set image.backend.repository=gcr.io/todoapp-autoscaling-demo/todoapp-backend \
  --set image.backend.tag=latest \
  --set image.frontend.repository=gcr.io/todoapp-autoscaling-demo/todoapp-frontend \
  --set image.frontend.tag=latest \
  --set autoscaling.enabled=true \
  --wait \
  --timeout 10m

# Verificar deployment
helm list -n todoapp
```

---

## Verificación y Monitoreo

### Verificar Estado del Cluster

```bash
# Ver nodos
kubectl get nodes

# Salida esperada:
# NAME                                       STATUS   ROLES    AGE
# gke-...-default-pool-abc123                Ready    <none>   10m
# gke-...-default-pool-def456                Ready    <none>   10m

# Ver recursos del cluster
kubectl top nodes
```

### Verificar Pods

```bash
# Ver todos los pods
kubectl get pods -n todoapp

# Salida esperada:
# NAME                               READY   STATUS    RESTARTS   AGE
# todoapp-backend-xxx                1/1     Running   0          5m
# todoapp-backend-yyy                1/1     Running   0          5m
# todoapp-frontend-zzz               1/1     Running   0          5m
# todoapp-frontend-www               1/1     Running   0          5m
# todoapp-postgres-aaa               1/1     Running   0          5m

# Ver detalles de un pod
kubectl describe pod <pod-name> -n todoapp

# Ver logs de un pod
kubectl logs <pod-name> -n todoapp

# Logs en tiempo real
kubectl logs -f <pod-name> -n todoapp
```

### Verificar Services

```bash
# Ver services
kubectl get svc -n todoapp

# Salida esperada:
# NAME               TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# todoapp-backend    ClusterIP      10.xx.yy.10    <none>           5000/TCP
# todoapp-frontend   LoadBalancer   10.xx.yy.20    34.42.115.79     3000:31234/TCP
# todoapp-postgres   ClusterIP      10.xx.yy.30    <none>           5432/TCP

# Esperar a que EXTERNAL-IP esté asignada (puede tardar 2-3 min)
kubectl get svc todoapp-frontend -n todoapp --watch
```

### Verificar HPA (Horizontal Pod Autoscaler)

```bash
# Ver estado de HPA
kubectl get hpa -n todoapp

# Salida esperada:
# NAME                  REFERENCE                  TARGETS         MINPODS   MAXPODS   REPLICAS
# todoapp-backend-hpa   Deployment/todoapp-backend 2%/50%, 15%/70%   2         10        2
# todoapp-frontend-hpa  Deployment/todoapp-frontend 1%/60%, 10%/75%  2         8         2

# Ver detalles de HPA
kubectl describe hpa todoapp-backend-hpa -n todoapp

# Monitoreo continuo
watch kubectl get hpa -n todoapp
```

### Verificar PersistentVolumes

```bash
# Ver PVCs
kubectl get pvc -n todoapp

# Salida esperada:
# NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES
# postgres-pvc   Bound    pvc-abc123-def456-...                      10Gi       RWO

# Ver PVs
kubectl get pv
```

### Acceder a la Aplicación

```bash
# Obtener IP externa
EXTERNAL_IP=$(kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Aplicación disponible en: http://$EXTERNAL_IP:3000"

# Abrir en navegador
xdg-open "http://$EXTERNAL_IP:3000"  # Linux
open "http://$EXTERNAL_IP:3000"      # macOS
```

### Probar API directamente

```bash
# Obtener IP externa
EXTERNAL_IP=$(kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Probar endpoint /api/tasks
curl http://$EXTERNAL_IP:3000/api/tasks

# Salida esperada:
# [{"id":1,"task":"Comprar pan","completed":false},...]

# Crear nueva tarea
curl -X POST http://$EXTERNAL_IP:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"task":"Nueva tarea desde API"}'
```

---

## Gestión del Cluster

### Escalar Manualmente (Sin HPA)

```bash
# Deshabilitar HPA temporalmente (opcional)
kubectl delete hpa todoapp-backend-hpa -n todoapp

# Escalar deployment manualmente
kubectl scale deployment todoapp-backend --replicas=5 -n todoapp

# Verificar
kubectl get pods -n todoapp

# Re-habilitar HPA
helm upgrade todoapp helm/todoapp -n todoapp --reuse-values
```

### Actualizar Aplicación

```bash
# Opción 1: Rebuild imagen y push
docker build -t gcr.io/todoapp-autoscaling-demo/todoapp-backend:v2 backend/
docker push gcr.io/todoapp-autoscaling-demo/todoapp-backend:v2

# Actualizar deployment
kubectl set image deployment/todoapp-backend \
  todoapp-backend=gcr.io/todoapp-autoscaling-demo/todoapp-backend:v2 \
  -n todoapp

# Opción 2: Re-ejecutar Ansible
ansible-playbook ansible/main.yml --tags build,deploy
```

### Rollback de Deployment

```bash
# Ver historial de deployments
kubectl rollout history deployment/todoapp-backend -n todoapp

# Rollback a versión anterior
kubectl rollout undo deployment/todoapp-backend -n todoapp

# Rollback a revisión específica
kubectl rollout undo deployment/todoapp-backend --to-revision=2 -n todoapp
```

### Restart de Pods

```bash
# Restart deployment (crea nuevos pods)
kubectl rollout restart deployment/todoapp-backend -n todoapp

# Verificar rollout
kubectl rollout status deployment/todoapp-backend -n todoapp
```

---

## Troubleshooting

### Pod en CrashLoopBackOff

```bash
# Ver logs del pod
kubectl logs <pod-name> -n todoapp

# Ver logs del container anterior (si crasheó)
kubectl logs <pod-name> -n todoapp --previous

# Describir pod (ver eventos)
kubectl describe pod <pod-name> -n todoapp

# Ejecutar shell en pod (si está corriendo)
kubectl exec -it <pod-name> -n todoapp -- /bin/sh
```

### Service Sin IP Externa

```bash
# Verificar eventos del service
kubectl describe svc todoapp-frontend -n todoapp

# Ver eventos del namespace
kubectl get events -n todoapp --sort-by='.lastTimestamp'

# Verificar quotas de GCP
gcloud compute project-info describe --project=todoapp-autoscaling-demo
```

### HPA No Escala

```bash
# Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# Ver métricas disponibles
kubectl top pods -n todoapp

# Si "error: metrics not available":
# Reinstalar metrics-server
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}

# Verificar logs de HPA controller
kubectl logs -n kube-system -l k8s-app=kube-controller-manager
```

### Cluster Autoscaler No Añade Nodos

```bash
# Verificar logs de cluster autoscaler
kubectl logs -f -n kube-system -l k8s-app=cluster-autoscaler

# Verificar eventos del cluster
kubectl get events -n kube-system | grep cluster-autoscaler

# Verificar configuración de node pool en GCP
gcloud container clusters describe todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --format="value(autoscaling)"
```

### Problemas de Conectividad Backend-Postgres

```bash
# Verificar que postgres service existe
kubectl get svc todoapp-postgres -n todoapp

# Probar conectividad desde backend pod
kubectl exec -it <backend-pod> -n todoapp -- /bin/sh
# Dentro del pod:
nc -zv todoapp-postgres 5432
# Debe mostrar: todoapp-postgres (10.x.x.x:5432) open

# Verificar variables de entorno en backend
kubectl exec <backend-pod> -n todoapp -- env | grep POSTGRES
```

### Frontend No Muestra Tareas

```bash
# Verificar logs de frontend
kubectl logs <frontend-pod> -n todoapp

# Probar API desde fuera del cluster
EXTERNAL_IP=$(kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$EXTERNAL_IP:3000/api/tasks

# Verificar nginx config en frontend pod
kubectl exec <frontend-pod> -n todoapp -- cat /etc/nginx/conf.d/default.conf

# Probar proxy desde dentro del pod
kubectl exec -it <frontend-pod> -n todoapp -- /bin/sh
# Dentro del pod:
curl http://todoapp-backend:5000/tasks
```

---

## Limpieza de Recursos

### Opción 1: Limpieza con Ansible

```bash
# Ejecutar playbook de limpieza
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml

# Confirmar cuando se solicite
```

### Opción 2: Limpieza Manual

```bash
# 1. Eliminar Helm release
helm uninstall todoapp -n todoapp

# 2. Eliminar namespace
kubectl delete namespace todoapp

# 3. Eliminar cluster GKE
gcloud container clusters delete todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --quiet

# 4. Eliminar VPC network
gcloud compute networks subnets delete todoapp-subnet \
  --region=us-central1 \
  --quiet

gcloud compute networks delete todoapp-network --quiet

# 5. Eliminar imágenes en GCR (opcional)
gcloud container images delete gcr.io/todoapp-autoscaling-demo/todoapp-backend:latest --quiet
gcloud container images delete gcr.io/todoapp-autoscaling-demo/todoapp-frontend:latest --quiet
```

### Verificar Limpieza

```bash
# Verificar que cluster no existe
gcloud container clusters list

# Verificar que network no existe
gcloud compute networks list

# Verificar que no hay recursos en GCE
gcloud compute instances list
gcloud compute disks list
```

### Verificar Costos Post-Limpieza

```bash
# Ver uso actual
gcloud billing accounts describe XXXXXX-XXXXXX-XXXXXX

# Ver recursos activos en proyecto
gcloud asset search-all-resources \
  --scope=projects/todoapp-autoscaling-demo \
  --asset-types=compute.googleapis.com/Instance,compute.googleapis.com/Disk
```

---

## Comandos de Referencia Rápida

### Despliegue

```bash
# Completo (Ansible)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml
```

### Monitoreo

```bash
# Dashboard completo
watch "kubectl get nodes && echo && kubectl get pods -n todoapp && echo && kubectl get hpa -n todoapp"
```

### Verificación

```bash
# Check rápido
kubectl get all -n todoapp
```

### Logs

```bash
# Todos los logs de backend
kubectl logs -l app=todoapp-backend -n todoapp --tail=100 -f
```

### Limpieza

```bash
# Completa
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml
```

---

## Conclusión

Este documento proporciona todos los comandos necesarios para:
- ✅ Configurar ambiente GCP desde cero
- ✅ Desplegar aplicación con Ansible o manualmente
- ✅ Verificar y monitorear todos los componentes
- ✅ Troubleshoot problemas comunes
- ✅ Limpiar recursos completamente

Para una guía simplificada de prueba de autoscaling, ver: `05-MANUAL-AUTOSCALING-TEST.md`
