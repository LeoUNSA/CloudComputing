# ToDoApp - Demostración de Autoscaling en GCP con Ansible

Aplicación web de tareas (ToDo) desplegada en **Google Kubernetes Engine (GKE)** utilizando **Ansible** como herramienta de Infrastructure as Code (IaC) y configurada con **autoscaling automático** a nivel de pods y nodos.

---

## 🎯 Características Principales

- **Ansible** como única herramienta IaC (no usa Terraform, CloudFormation, etc.)
- **HPA (Horizontal Pod Autoscaler)** para escalar pods automáticamente
- **Cluster Autoscaler** de GKE para escalar nodos según demanda
- **Despliegue completamente automatizado** con un solo comando
- **Monitoreo de métricas** con metrics-server
- **Load testing** integrado para demostrar autoscaling

---

## 📦 Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| **IaC** | Ansible |
| **Cloud** | Google Cloud Platform (GKE) |
| **Orquestación** | Kubernetes + Helm |
| **Backend** | Node.js + Express + PostgreSQL |
| **Frontend** | React + Nginx |
| **Autoscaling** | HPA v2 + GKE Cluster Autoscaler |
| **Registro** | Google Container Registry (GCR) |

---

## 🚀 Quick Start

### Prerequisitos

```bash
# Herramientas necesarias
- gcloud CLI
- kubectl
- helm
- docker
- ansible

# Cuenta GCP con billing habilitado
```

### Instalación (Arch Linux)

```bash
sudo pacman -S google-cloud-sdk kubectl helm docker ansible
sudo systemctl start docker
```

### Configuración y Despliegue

```bash
# 1. Clonar repositorio
git clone <repository-url>
cd ToDoApp

# 2. Autenticar en GCP
gcloud auth login
gcloud config set project <TU_PROJECT_ID>

# 3. Configurar Docker para GCR
gcloud auth configure-docker

# 4. Editar variables de Ansible
nano ansible/inventories/gcp/group_vars/all.yml
# Cambiar: gcp_project_id: "TU_PROJECT_ID"

# 5. Vincular billing
gcloud billing projects link <TU_PROJECT_ID> --billing-account=<BILLING_ID>

# 6. Desplegar (10-15 minutos)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml

# 7. Obtener URL de la aplicación
kubectl get svc todoapp-frontend -n todoapp
# Acceder a http://<EXTERNAL-IP>:3000
```

---

## 🔧 Configuración de Autoscaling

### HPA (Horizontal Pod Autoscaler)

Configurado en `helm/todoapp/templates/hpa.yaml`:

**Backend:**
- Min replicas: 2
- Max replicas: 10
- Target CPU: 50%
- Target Memory: 70%

**Frontend:**
- Min replicas: 2
- Max replicas: 8
- Target CPU: 60%
- Target Memory: 75%

### Cluster Autoscaler

Configurado en la creación del cluster GKE:

- Min nodes: 2
- Max nodes: 10
- Machine type: e2-standard-2 (2 vCPU, 8 GB RAM)

### Variables de Configuración

Todas las variables están centralizadas en:

```yaml
# ansible/inventories/gcp/group_vars/all.yml

gcp_project_id: "tu-proyecto-id"
gcp_region: "us-central1"
gcp_zone: "us-central1-a"

gke_node_pool:
  min_node_count: 2
  max_node_count: 10
  machine_type: "e2-standard-2"

autoscaling:
  backend:
    min_replicas: 2
    max_replicas: 10
    target_cpu_utilization: 50
    target_memory_utilization: 70
  frontend:
    min_replicas: 2
    max_replicas: 8
    target_cpu_utilization: 60
    target_memory_utilization: 75
```

---

## 🧪 Prueba de Autoscaling

### Generar Carga

```bash
# Crear 5 generadores de carga
for i in {1..5}; do
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
done
```

### Monitorear Escalado

```bash
# Terminal 1: Ver HPA
watch -n 2 'kubectl get hpa -n todoapp'

# Terminal 2: Ver nodos
watch -n 5 'kubectl get nodes'

# Terminal 3: Ver pods
watch -n 2 'kubectl get pods -n todoapp'
```

### Resultado Esperado

```
T=0:    2 pods backend, 2 nodos, CPU ~2%
        ↓ Generar carga
T=1min: CPU sube a 85%, HPA escala a 4 pods
T=2min: HPA escala a 6 pods
T=3min: HPA escala a 8 pods
T=4min: HPA escala a 10 pods (máximo)
T=5min: Algunos pods quedan "Pending" (sin recursos)
T=7min: Cluster Autoscaler añade nodo 3
        Todos los pods pasan a "Running"
```

### Eliminar Carga

```bash
# Detener generadores
kubectl delete pod -n todoapp -l run=load-gen-1

# Scale-down automático (5-10 minutos)
# - HPA reduce pods gradualmente
# - Cluster Autoscaler elimina nodos infrautilizados
```

---

## 📁 Estructura del Proyecto

```
ToDoApp/
├── ansible/                          # Infrastructure as Code
│   ├── main.yml                      # Playbook principal
│   ├── cleanup.yml                   # Playbook de limpieza
│   ├── inventories/gcp/
│   │   └── group_vars/all.yml        # Variables de configuración
│   └── tasks/
│       ├── setup-gke-cluster.yml     # Crear cluster GKE
│       ├── build-and-push-images.yml # Build/push Docker
│       └── deploy-app.yml            # Deploy con Helm
│
├── backend/                          # Backend Node.js
│   ├── server.js                     # API + endpoint /stress
│   └── Dockerfile
│
├── frontend/                         # Frontend React
│   ├── nginx.conf                    # Reverse proxy /api
│   └── Dockerfile
│
├── helm/todoapp/                     # Helm Chart
│   ├── values.yaml                   # Configuración
│   └── templates/
│       ├── hpa.yaml                  # HPA para backend/frontend
│       ├── backend-deployment.yaml
│       ├── frontend-deployment.yaml
│       └── postgres-deployment.yaml
│
├── docs/                             # Documentación detallada
│   ├── 01-ANSIBLE-DEPLOYMENT.md
│   ├── 02-AUTOSCALING-MECHANISMS.md
│   ├── 03-CLOUD-ARCHITECTURE.md
│   ├── 04-DEPLOYMENT-COMMANDS.md
│   ├── 05-MANUAL-AUTOSCALING-TEST.md
│   └── 06-LOAD-GENERATION-INTERNALS.md
│
└── load-testing/                     # Scripts de pruebas
    ├── simple-load-test.sh
    ├── monitor-autoscaling.sh
    └── extreme-load-test.sh
```

---

## 🤖 Automatización con Ansible

### Playbooks Disponibles

```bash
# Despliegue completo
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml

# Solo crear cluster
ansible-playbook ansible/main.yml --tags cluster

# Solo build/push imágenes
ansible-playbook ansible/main.yml --tags build,images

# Solo deploy aplicación
ansible-playbook ansible/main.yml --tags deploy

# Limpieza completa
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml
```

### Lo que Hace Ansible

1. **Setup GKE Cluster** (`tasks/setup-gke-cluster.yml`):
   - Habilita APIs de GCP (Compute, Container, Registry)
   - Crea VPC network y subnet
   - Crea cluster GKE con autoscaling habilitado
   - Configura kubectl credentials
   - Crea namespace `todoapp`

2. **Build & Push Images** (`tasks/build-and-push-images.yml`):
   - Construye imagen Docker del backend
   - Construye imagen Docker del frontend
   - Sube ambas imágenes a GCR

3. **Deploy App** (`tasks/deploy-app.yml`):
   - Instala metrics-server (si no existe)
   - Genera values YAML para Helm con configuraciones de autoscaling
   - Despliega aplicación usando Helm chart
   - Espera a que deployments estén listos
   - Muestra IP del LoadBalancer

---

## 📊 Arquitectura Cloud

```
Internet
   │
   ▼
Google Cloud Load Balancer (IP externa)
   │
   ▼
Frontend Pods (2-8 réplicas) ─── HPA
   │ (nginx reverse proxy)
   │
   ▼ /api/*
Backend Pods (2-10 réplicas) ─── HPA
   │
   ▼
PostgreSQL Pod
   │
   ▼
Persistent Disk (10GB)

Nodos: 2-10 (e2-standard-2) ─── Cluster Autoscaler
```

### Componentes de Red

- **VPC Network**: `todoapp-network` (10.0.0.0/24)
- **Service Frontend**: LoadBalancer (expuesto a Internet)
- **Service Backend**: ClusterIP (solo interno)
- **Service Postgres**: ClusterIP (solo interno)
- **Nginx Reverse Proxy**: `/api/*` → `http://todoapp-backend:5000/*`

---

## 🔍 Verificación

```bash
# Ver estado del cluster
kubectl get nodes

# Ver pods
kubectl get pods -n todoapp

# Ver HPA
kubectl get hpa -n todoapp

# Ver services
kubectl get svc -n todoapp

# Ver métricas
kubectl top pods -n todoapp
kubectl top nodes

# Logs de un pod
kubectl logs -n todoapp <pod-name>

# Acceder a la aplicación
kubectl get svc todoapp-frontend -n todoapp
# http://<EXTERNAL-IP>:3000
```

---

## 🗑️ Limpieza

```bash
# Opción 1: Ansible (recomendado)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml

# Opción 2: Manual
helm uninstall todoapp -n todoapp
kubectl delete namespace todoapp
gcloud container clusters delete todoapp-autoscaling-cluster --zone=us-central1-a --quiet
gcloud compute networks subnets delete todoapp-subnet --region=us-central1 --quiet
gcloud compute networks delete todoapp-network --quiet
```

---

## 📚 Documentación Extendida

Para información detallada, consultar:

- **[SETUP-GUIDE.md](SETUP-GUIDE.md)** - Guía completa de configuración
- **[docs/01-ANSIBLE-DEPLOYMENT.md](docs/01-ANSIBLE-DEPLOYMENT.md)** - Funcionamiento de Ansible
- **[docs/02-AUTOSCALING-MECHANISMS.md](docs/02-AUTOSCALING-MECHANISMS.md)** - HPA y Cluster Autoscaler
- **[docs/03-CLOUD-ARCHITECTURE.md](docs/03-CLOUD-ARCHITECTURE.md)** - Arquitectura cloud
- **[docs/04-DEPLOYMENT-COMMANDS.md](docs/04-DEPLOYMENT-COMMANDS.md)** - Comandos de despliegue
- **[docs/05-MANUAL-AUTOSCALING-TEST.md](docs/05-MANUAL-AUTOSCALING-TEST.md)** - Pruebas de autoscaling
- **[docs/06-LOAD-GENERATION-INTERNALS.md](docs/06-LOAD-GENERATION-INTERNALS.md)** - Generación de tráfico

---

## ⚙️ Configuración Personalizada

### Cambiar Región/Zona

```yaml
# ansible/inventories/gcp/group_vars/all.yml
gcp_region: "europe-west1"
gcp_zone: "europe-west1-b"
```

### Ajustar Autoscaling

```yaml
# Más agresivo
autoscaling:
  backend:
    min_replicas: 1
    max_replicas: 20
    target_cpu_utilization: 30  # Escala más rápido

# Más conservador
autoscaling:
  backend:
    min_replicas: 3
    max_replicas: 6
    target_cpu_utilization: 80  # Tolera más carga
```

### Cambiar Tipo de Máquina

```yaml
gke_node_pool:
  machine_type: "e2-standard-4"  # 4 vCPU, 16 GB RAM
  # o
  machine_type: "e2-highcpu-8"   # 8 vCPU, 8 GB RAM
```

---

## 🛠️ Troubleshooting

### HPA No Escala

```bash
# Verificar metrics-server
kubectl top pods -n todoapp

# Si falla, reinstalar
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}
```

### Cluster Autoscaler No Añade Nodos

```bash
# Ver logs del autoscaler
kubectl logs -n kube-system -l k8s-app=cluster-autoscaler

# Verificar configuración
gcloud container clusters describe todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --format="value(autoscaling)"
```

### Pods en CrashLoopBackOff

```bash
# Ver logs
kubectl logs <pod-name> -n todoapp

# Describir pod
kubectl describe pod <pod-name> -n todoapp

# Ver eventos
kubectl get events -n todoapp --sort-by='.lastTimestamp'
```

---

## 📊 Métricas y Costos

### Recursos Utilizados

**Estado inicial (mínimo)**:
- 2 nodos e2-standard-2
- 2 pods backend
- 2 pods frontend
- 1 pod postgres
- **Costo estimado**: ~$100-120 USD/mes

**Estado con carga (máximo)**:
- 10 nodos e2-standard-2
- 10 pods backend
- 8 pods frontend
- 1 pod postgres
- **Costo estimado**: ~$500-600 USD/mes (solo durante carga)

**Ventaja del autoscaling**: Pagas solo por lo que usas, escala automáticamente según demanda.

---

## 🎓 Conceptos Clave

### HPA (Horizontal Pod Autoscaler)
Escala el **número de réplicas** de un Deployment basándose en métricas (CPU, Memory). Definido en `helm/todoapp/templates/hpa.yaml`.

### Cluster Autoscaler
Escala el **número de nodos** del cluster cuando hay pods en estado Pending por falta de recursos. Configurado al crear el cluster GKE.

### Ansible como IaC
Automatiza la creación de infraestructura usando comandos `gcloud` y `kubectl` dentro de playbooks YAML. Alternativa a Terraform, más simple para este caso de uso.

### Nginx Reverse Proxy
El frontend usa nginx para hacer proxy de `/api/*` al backend, evitando problemas de CORS y simplificando la configuración.

---

## 🤝 Aplicación de Ejemplo

La aplicación ToDo es un ejemplo simple para demostrar autoscaling. Incluye:

- **Backend**: API REST con endpoints CRUD + `/stress` para load testing
- **Frontend**: Interfaz React para gestionar tareas
- **Database**: PostgreSQL con datos de ejemplo

El enfoque principal es la **infraestructura y autoscaling**, no la funcionalidad de la aplicación.

---

## 📜 Licencia

Proyecto educacional - Uso libre

---

## 🔗 Enlaces Útiles

- [Documentación GKE Autoscaling](https://cloud.google.com/kubernetes-engine/docs/concepts/horizontalpodautoscaler)
- [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Helm Charts](https://helm.sh/docs/topics/charts/)
