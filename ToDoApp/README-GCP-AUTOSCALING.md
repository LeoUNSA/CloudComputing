# 🚀 TodoApp - AutoScaling en Google Cloud con Ansible y Kubernetes

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Arquitectura](#arquitectura)
- [Requisitos Previos](#requisitos-previos)
- [Configuración de AutoScaling](#configuración-de-autoscaling)
- [Instalación y Despliegue](#instalación-y-despliegue)
- [Pruebas de AutoScaling](#pruebas-de-autoscaling)
- [Monitoreo](#monitoreo)
- [Limpieza de Recursos](#limpieza-de-recursos)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Descripción General

Este proyecto implementa **AutoScaling completo** tanto a nivel de **pods** (Horizontal Pod Autoscaler) como de **nodos** (Cluster Autoscaler) en **Google Kubernetes Engine (GKE)** usando **Ansible** como herramienta de Infrastructure as Code (IaC).

### Características de AutoScaling

| Tipo | Componente | Configuración |
|------|------------|---------------|
| **Pod Autoscaling** | Backend | 2-10 réplicas (CPU: 50%, Mem: 70%) |
| **Pod Autoscaling** | Frontend | 2-8 réplicas (CPU: 60%, Mem: 75%) |
| **Node Autoscaling** | Cluster GKE | 2-10 nodos (e2-standard-2) |

### ✨ Características Principales

- ✅ **Cluster GKE** con Cluster Autoscaler habilitado
- ✅ **HPA (Horizontal Pod Autoscaler)** para backend y frontend
- ✅ **Métricas de CPU y Memoria** para autoscaling
- ✅ **Políticas de escalado** optimizadas (scale-up rápido, scale-down gradual)
- ✅ **Deployment automatizado** con Ansible
- ✅ **Scripts de prueba de carga** incluidos
- ✅ **Monitoreo en tiempo real** de métricas y escalado

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     Google Cloud Platform                    │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              GKE Cluster (Autoscaling)                │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐     │  │
│  │  │          Node Pool (2-10 nodes)              │     │  │
│  │  │                                                │     │  │
│  │  │  ┌────────────────┐  ┌────────────────┐     │     │  │
│  │  │  │  Backend Pods  │  │ Frontend Pods  │     │     │  │
│  │  │  │   (HPA 2-10)   │  │   (HPA 2-8)    │     │     │  │
│  │  │  │                │  │                │     │     │  │
│  │  │  │  CPU: 50%      │  │  CPU: 60%      │     │     │  │
│  │  │  │  Mem: 70%      │  │  Mem: 75%      │     │     │  │
│  │  │  └────────────────┘  └────────────────┘     │     │  │
│  │  │                                                │     │  │
│  │  │  ┌────────────────┐                          │     │  │
│  │  │  │   PostgreSQL   │                          │     │  │
│  │  │  │   (1 replica)  │                          │     │  │
│  │  │  └────────────────┘                          │     │  │
│  │  └──────────────────────────────────────────────┘     │  │
│  │                                                         │  │
│  │  ┌──────────────────────────────────────────────┐     │  │
│  │  │           Metrics Server                      │     │  │
│  │  │         (HPA Data Source)                     │     │  │
│  │  └──────────────────────────────────────────────┘     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         Container Registry (GCR)                      │  │
│  │   - todoapp-backend:latest                            │  │
│  │   - todoapp-frontend:latest                           │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Flujo de AutoScaling

```
1. Carga Alta → Métricas Aumentan (CPU/Mem)
                    ↓
2. Metrics Server → Recolecta métricas cada 15s
                    ↓
3. HPA Controller → Detecta threshold excedido
                    ↓
4. Scale-Up Pods → Crea nuevos pods (30s scale-up)
                    ↓
5. Si no hay recursos → Cluster Autoscaler activa
                    ↓
6. Nuevos Nodos → GKE provisiona nodos adicionales
                    ↓
7. Pods Programados → Nuevos pods en nuevos nodos
                    ↓
8. Carga Baja → Scale-Down gradual (5min stabilization)
```

---

## 📋 Requisitos Previos

### 1. Software Necesario

```bash
# Ansible
sudo apt update
sudo apt install -y ansible

# Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# kubectl
gcloud components install kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Docker (para build de imágenes)
sudo apt install -y docker.io
sudo usermod -aG docker $USER
```

### 2. Cuenta de GCP

1. **Crear proyecto en GCP**:
   ```bash
   export GCP_PROJECT_ID="tu-proyecto-id"
   gcloud projects create $GCP_PROJECT_ID
   gcloud config set project $GCP_PROJECT_ID
   ```

2. **Habilitar facturación**:
   - Ve a: https://console.cloud.google.com/billing
   - Vincula el proyecto con una cuenta de facturación

3. **Crear Service Account**:
   ```bash
   # Crear service account
   gcloud iam service-accounts create todoapp-deployer \
       --display-name="TodoApp Deployer"
   
   # Asignar roles necesarios
   gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
       --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
       --role="roles/container.admin"
   
   gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
       --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
       --role="roles/compute.admin"
   
   gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
       --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
       --role="roles/storage.admin"
   
   # Crear y descargar key
   mkdir -p ~/.gcp
   gcloud iam service-accounts keys create ~/.gcp/credentials.json \
       --iam-account=todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com
   ```

4. **Configurar variables de entorno**:
   ```bash
   export GCP_PROJECT_ID="tu-proyecto-id"
   export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"
   
   # Agregar a ~/.bashrc para persistencia
   echo "export GCP_PROJECT_ID=\"$GCP_PROJECT_ID\"" >> ~/.bashrc
   echo "export GCP_CREDENTIALS_FILE=\"$HOME/.gcp/credentials.json\"" >> ~/.bashrc
   ```

### 3. Cuotas de GCP

Verifica que tienes cuotas suficientes:
- **CPUs**: Mínimo 20 vCPUs en us-central1
- **IP Addresses**: Mínimo 10 IPs
- **Persistent Disk**: 500 GB

```bash
# Ver cuotas actuales
gcloud compute project-info describe --project=$GCP_PROJECT_ID
```

---

## ⚙️ Configuración de AutoScaling

### Configuración de Variables

Edita `ansible/inventories/gcp/group_vars/all.yml`:

```yaml
# Proyecto GCP
gcp_project_id: "tu-proyecto-id"
gcp_region: "us-central1"
gcp_zone: "us-central1-a"

# Cluster Configuration
gke_cluster_name: "todoapp-autoscaling-cluster"

# Node Pool (Cluster Autoscaler)
gke_node_pool:
  name: "default-pool"
  initial_node_count: 2        # Nodos iniciales
  min_node_count: 2            # Mínimo de nodos
  max_node_count: 10           # Máximo de nodos
  machine_type: "e2-standard-2" # 2 vCPUs, 8GB RAM
  
# HPA Configuration - Backend
autoscaling:
  backend:
    min_replicas: 2
    max_replicas: 10
    target_cpu_utilization: 50      # Scale cuando CPU > 50%
    target_memory_utilization: 70   # Scale cuando Mem > 70%
    
  # HPA Configuration - Frontend
  frontend:
    min_replicas: 2
    max_replicas: 8
    target_cpu_utilization: 60      # Scale cuando CPU > 60%
    target_memory_utilization: 75   # Scale cuando Mem > 75%
```

### Políticas de Escalado

Las políticas están configuradas en `helm/todoapp/templates/hpa.yaml`:

**Scale-Up (Rápido)**:
- Sin estabilización (0 segundos)
- Máximo: 100% o 4 pods cada 30 segundos
- Política: Tomar el máximo

**Scale-Down (Gradual)**:
- Estabilización: 5 minutos
- Máximo: 50% o 2 pods cada 60 segundos
- Política: Tomar el mínimo

---

## 🚀 Instalación y Despliegue

### Método 1: Despliegue Completo (Recomendado)

```bash
cd ansible

# Ejecutar el playbook principal
ansible-playbook main.yml

# Este playbook ejecuta automáticamente:
# 1. Creación del cluster GKE
# 2. Build y push de imágenes a GCR
# 3. Despliegue de la aplicación con Helm
```

### Método 2: Paso a Paso

```bash
cd ansible

# Paso 1: Crear cluster GKE
ansible-playbook setup-gke-cluster.yml

# Paso 2: Build y push de imágenes
ansible-playbook build-and-push-images.yml

# Paso 3: Desplegar aplicación
ansible-playbook deploy-app.yml
```

### Método 3: Tags Específicos

```bash
# Solo crear cluster
ansible-playbook main.yml --tags cluster

# Solo build de imágenes
ansible-playbook main.yml --tags build

# Solo deployment
ansible-playbook main.yml --tags deploy
```

### Verificar Despliegue

```bash
# Verificar cluster
kubectl cluster-info
kubectl get nodes

# Verificar aplicación
kubectl get all -n todoapp

# Verificar HPA
kubectl get hpa -n todoapp

# Obtener URL de acceso
kubectl get svc todoapp-frontend -n todoapp
```

---

## 🧪 Pruebas de AutoScaling

### 1. Monitoreo en Tiempo Real

```bash
cd load-testing

# Iniciar monitor (en una terminal separada)
./monitor-autoscaling.sh
```

Este script muestra:
- Estado de HPAs (targets, replicas)
- Pods actuales y su distribución
- Métricas de CPU/Memoria
- Estado de nodos
- Eventos de escalado recientes

### 2. Prueba de Carga Básica

```bash
# Generar carga moderada (5 minutos)
./simple-load-test.sh

# Con configuración personalizada
CONCURRENT_WORKERS=20 DURATION=600 ./simple-load-test.sh
```

**Resultado esperado**:
- Backend escala de 2 a 4-6 pods
- Frontend puede escalar ligeramente
- Nodos se mantienen en 2-3

### 3. Prueba de Carga Avanzada

```bash
# Test con monitoreo integrado
./run-load-test.sh

# Configuración personalizada
CONCURRENT_REQUESTS=100 TOTAL_REQUESTS=10000 DURATION=600 ./run-load-test.sh
```

**Resultado esperado**:
- Backend escala hacia 8-10 pods
- Frontend escala a 4-6 pods
- Cluster puede agregar 1-2 nodos nuevos

### 4. Prueba Extrema (Escalado de Nodos)

⚠️ **ADVERTENCIA**: Esta prueba generará costos significativos en GCP.

```bash
# Generar carga extrema
./extreme-load-test.sh

# Esto creará 20 pods generadores de carga
```

**Resultado esperado**:
- Backend escala a máximo (10 pods)
- Frontend escala a máximo (8 pods)
- Cluster escala a 5-8 nodos
- **Costos**: ~$2-5 USD durante la prueba

### Detener Pruebas de Carga

```bash
# Detener generadores de carga
kubectl delete pods -n todoapp -l run=load-generator

# Limpiar recursos
kubectl delete pod load-generator -n todoapp --ignore-not-found
```

---

## 📊 Monitoreo

### Comandos de Monitoreo Útiles

```bash
# Ver HPAs en tiempo real
kubectl get hpa -n todoapp -w

# Ver pods y su uso de recursos
kubectl top pods -n todoapp

# Ver nodos y su uso
kubectl top nodes

# Ver eventos de escalado
kubectl get events -n todoapp --sort-by='.lastTimestamp' | grep -i scale

# Describe HPA para detalles
kubectl describe hpa -n todoapp

# Ver logs de pods específicos
kubectl logs -n todoapp -l app.kubernetes.io/component=backend --tail=100

# Ver distribución de pods en nodos
kubectl get pods -n todoapp -o wide
```

### Métricas Clave

| Métrica | Comando | Threshold |
|---------|---------|-----------|
| CPU Backend | `kubectl top pods -n todoapp -l component=backend` | > 50% → Scale Up |
| Mem Backend | `kubectl top pods -n todoapp -l component=backend` | > 70% → Scale Up |
| CPU Frontend | `kubectl top pods -n todoapp -l component=frontend` | > 60% → Scale Up |
| Replicas Backend | `kubectl get hpa -n todoapp` | 2-10 pods |
| Replicas Frontend | `kubectl get hpa -n todoapp` | 2-8 pods |
| Nodos Cluster | `kubectl get nodes` | 2-10 nodos |

### Dashboard de Métricas (GCP Console)

1. Ve a: https://console.cloud.google.com/kubernetes/clusters
2. Selecciona tu cluster → "Workloads"
3. Observa:
   - CPU y Memoria por pod
   - Distribución de pods
   - Eventos de autoscaling
   - Utilización de nodos

---

## 🧹 Limpieza de Recursos

### Opción 1: Usando Ansible (Recomendado)

```bash
cd ansible
ansible-playbook cleanup.yml
```

Este playbook:
1. Solicita confirmación
2. Elimina el release de Helm
3. Elimina el namespace
4. Elimina el cluster GKE
5. Elimina la subnet
6. Elimina la VPC network

### Opción 2: Manual

```bash
# Eliminar aplicación
helm uninstall todoapp -n todoapp
kubectl delete namespace todoapp

# Eliminar cluster GKE
gcloud container clusters delete todoapp-autoscaling-cluster \
    --zone=us-central1-a \
    --project=$GCP_PROJECT_ID \
    --quiet

# Eliminar red
gcloud compute networks subnets delete todoapp-subnet \
    --region=us-central1 \
    --project=$GCP_PROJECT_ID \
    --quiet

gcloud compute networks delete todoapp-network \
    --project=$GCP_PROJECT_ID \
    --quiet

# Eliminar imágenes de GCR (opcional)
gcloud container images delete gcr.io/$GCP_PROJECT_ID/todoapp-backend:latest --quiet
gcloud container images delete gcr.io/$GCP_PROJECT_ID/todoapp-frontend:latest --quiet
```

### Verificar Limpieza

```bash
# Verificar que no hay clusters
gcloud container clusters list --project=$GCP_PROJECT_ID

# Verificar que no hay recursos de red
gcloud compute networks list --project=$GCP_PROJECT_ID
```

---

## 🔧 Troubleshooting

### Problema: HPA no escala

**Síntoma**: HPA muestra `<unknown>` en targets

```bash
kubectl get hpa -n todoapp
# NAME                REFERENCE                      TARGETS         MINPODS   MAXPODS
# todoapp-backend     Deployment/todoapp-backend     <unknown>/50%   2         10
```

**Soluciones**:

1. Verificar metrics-server:
   ```bash
   kubectl get deployment metrics-server -n kube-system
   kubectl logs -n kube-system -l k8s-app=metrics-server
   ```

2. Reinstalar metrics-server:
   ```bash
   helm upgrade --install metrics-server metrics-server/metrics-server \
       --namespace kube-system \
       --set args[0]="--kubelet-insecure-tls" \
       --set args[1]="--kubelet-preferred-address-types=InternalIP"
   ```

3. Esperar 2-3 minutos para que se recolecten métricas

### Problema: Pods no tienen suficientes recursos

**Síntoma**: Pods en estado `Pending` o `CrashLoopBackOff`

```bash
kubectl describe pod <pod-name> -n todoapp
```

**Soluciones**:

1. Verificar recursos del nodo:
   ```bash
   kubectl describe nodes
   ```

2. Aumentar límites de recursos en `values.yaml`

3. Forzar escalado de nodos:
   ```bash
   # El cluster debería escalar automáticamente
   # Si no, verifica los logs del cluster autoscaler
   ```

### Problema: Cluster Autoscaler no añade nodos

**Síntoma**: Pods `Pending` pero sin nodos nuevos

**Soluciones**:

1. Verificar que el autoscaling está habilitado:
   ```bash
   gcloud container clusters describe todoapp-autoscaling-cluster \
       --zone=us-central1-a \
       --format="value(autoscaling)"
   ```

2. Verificar cuotas de GCP:
   ```bash
   gcloud compute project-info describe --project=$GCP_PROJECT_ID
   ```

3. Ver logs del cluster autoscaler:
   ```bash
   kubectl logs -n kube-system -l k8s-app=cluster-autoscaler
   ```

### Problema: LoadBalancer no obtiene IP externa

**Síntoma**: `EXTERNAL-IP` permanece en `<pending>`

```bash
kubectl get svc todoapp-frontend -n todoapp
```

**Soluciones**:

1. Esperar 2-3 minutos (puede tomar tiempo)

2. Verificar cuotas de IPs:
   ```bash
   gcloud compute addresses list --project=$GCP_PROJECT_ID
   ```

3. Describir el servicio:
   ```bash
   kubectl describe svc todoapp-frontend -n todoapp
   ```

### Problema: Ansible playbook falla en autenticación

**Síntoma**: Error `Could not authenticate`

**Soluciones**:

1. Verificar variables de entorno:
   ```bash
   echo $GCP_PROJECT_ID
   echo $GCP_CREDENTIALS_FILE
   ```

2. Verificar archivo de credenciales:
   ```bash
   test -f $GCP_CREDENTIALS_FILE && echo "OK" || echo "MISSING"
   ```

3. Re-autenticar:
   ```bash
   gcloud auth activate-service-account --key-file=$GCP_CREDENTIALS_FILE
   gcloud config set project $GCP_PROJECT_ID
   ```

### Problema: Imágenes no se pueden pull

**Síntoma**: `ImagePullBackOff` o `ErrImagePull`

**Soluciones**:

1. Verificar que las imágenes existen en GCR:
   ```bash
   gcloud container images list --repository=gcr.io/$GCP_PROJECT_ID
   ```

2. Verificar permisos:
   ```bash
   gcloud projects get-iam-policy $GCP_PROJECT_ID
   ```

3. Re-build y push:
   ```bash
   cd ansible
   ansible-playbook build-and-push-images.yml
   ```

---

## 📊 Costos Estimados

### Configuración Base (2 nodos)

| Recurso | Cantidad | Costo/hora | Costo/día | Costo/mes |
|---------|----------|------------|-----------|-----------|
| e2-standard-2 | 2 nodos | $0.134 | $3.22 | $96.60 |
| Persistent Disk (50GB) | 2 discos | $0.008 | $0.19 | $5.70 |
| LoadBalancer | 1 | $0.025 | $0.60 | $18.00 |
| **TOTAL** | - | **~$0.35** | **~$8.40** | **~$252** |

### Durante Autoscaling Extremo (10 nodos)

| Recurso | Cantidad | Costo/hora | Costo/día |
|---------|----------|------------|-----------|
| e2-standard-2 | 10 nodos | $0.670 | $16.08 |
| Persistent Disk (50GB) | 10 discos | $0.040 | $0.96 |
| LoadBalancer | 1 | $0.025 | $0.60 |
| **TOTAL** | - | **~$1.75** | **~$42** |

⚠️ **Recomendaciones**:
- Ejecuta pruebas de carga por períodos cortos
- Limpia recursos inmediatamente después de las pruebas
- Configura alertas de presupuesto en GCP
- Considera usar nodos preemptible para reducir costos

---

## 📚 Referencias

- [GKE Cluster Autoscaler](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler)
- [Kubernetes HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Ansible GCP Modules](https://docs.ansible.com/ansible/latest/collections/google/cloud/)
- [Helm Documentation](https://helm.sh/docs/)

---

## 🎓 Conceptos Clave

### Horizontal Pod Autoscaler (HPA)

- **Qué hace**: Escala el número de pods basándose en métricas
- **Métricas soportadas**: CPU, Memoria, Custom Metrics
- **Evaluación**: Cada 15 segundos por defecto
- **Algoritmo**: `desiredReplicas = ceil[currentReplicas * (currentMetric / targetMetric)]`

### Cluster Autoscaler

- **Qué hace**: Escala el número de nodos en el cluster
- **Cuándo escala UP**: Cuando hay pods `Pending` por falta de recursos
- **Cuándo escala DOWN**: Cuando nodos están sub-utilizados (< 50%) por > 10 minutos
- **Protecciones**: No elimina nodos con pods que no pueden ser reprogramados

### Metrics Server

- **Función**: Recolecta métricas de recursos (CPU/Mem) de kubelet
- **Frecuencia**: Cada 60 segundos
- **Almacenamiento**: In-memory (no persistente)
- **Clientes**: HPA, kubectl top, VPA

---

## ✅ Checklist de Validación

Usa este checklist para verificar que todo funciona correctamente:

- [ ] Cluster GKE creado y accesible
- [ ] Metrics-server instalado y funcionando
- [ ] HPAs creados y mostrando métricas válidas
- [ ] Pods backend y frontend corriendo
- [ ] LoadBalancer tiene IP externa
- [ ] Aplicación accesible desde navegador
- [ ] HPA escala pods bajo carga
- [ ] Cluster Autoscaler añade nodos cuando es necesario
- [ ] Scale-down funciona después de reducir carga
- [ ] Monitoreo muestra métricas en tiempo real

---

## 🤝 Contribuciones

Para mejoras o reportar issues:
1. Documenta el problema con logs y comandos ejecutados
2. Incluye la configuración de `group_vars/all.yml`
3. Especifica la versión de GKE, kubectl, Helm y Ansible

---

## 📄 Licencia

Este proyecto es parte de un ejercicio académico de Cloud Computing.

---

**¡Importante!** 🔴 No olvides ejecutar `ansible-playbook cleanup.yml` cuando termines para evitar cargos innecesarios en tu cuenta de GCP.
