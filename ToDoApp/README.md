# ToDoApp - Autoscaling Demo en GCP con Ansible

> **Demostración de autoscaling automático en Kubernetes (GKE) usando Ansible como IaC**

Aplicación web de tareas (ToDo) desplegada completamente en **Google Kubernetes Engine (GKE)** utilizando **Ansible** como única herramienta de Infrastructure as Code. Incluye autoscaling horizontal de pods (HPA) y autoscaling de nodos del cluster (Cluster Autoscaler).

---

## 🎯 Lo Importante: Despliegue con Ansible

Este proyecto está diseñado para **desplegar toda la infraestructura con Ansible**, desde cero hasta producción, con un solo comando:

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml
```

### ¿Qué hace este playbook?

1. ✅ **Habilita APIs de GCP** (Compute, Container, Container Registry)
2. ✅ **Crea infraestructura de red** (VPC custom y subnet)
3. ✅ **Crea cluster GKE** con autoscaling habilitado (2-10 nodos)
4. ✅ **Configura kubectl** con las credenciales del cluster
5. ✅ **Construye imágenes Docker** (backend y frontend)
6. ✅ **Sube imágenes a GCR** (Google Container Registry)
7. ✅ **Instala metrics-server** (si no está presente)
8. ✅ **Despliega la aplicación** vía Helm con HPA configurado
9. ✅ **Espera a que todo esté listo** y muestra la IP externa

**Tiempo estimado:** 8-12 minutos

### Destruir toda la infraestructura

Cuando termines, destruye todo para evitar cargos:

```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml
```

Esto elimina: cluster GKE, VPC, subnet, imágenes, load balancers, discos, etc.

---

## � Requisitos Previos

### 1. Instalar herramientas necesarias

```bash
# Arch Linux
sudo pacman -S google-cloud-sdk kubectl helm docker ansible

# Ubuntu/Debian
sudo apt update
sudo apt install google-cloud-sdk kubectl helm docker.io ansible

# Iniciar Docker
sudo systemctl start docker
```

### 2. Configurar GCP

```bash
# Autenticar
gcloud auth login

# Configurar proyecto (reemplaza con tu project ID)
gcloud config set project todoapp-autoscaling-demo

# Habilitar billing (REQUERIDO para GKE)
# Visita: https://console.cloud.google.com/billing

# Configurar Docker para GCR
gcloud auth configure-docker
```

### 3. Configurar variables de Ansible

Edita `ansible/inventories/gcp/group_vars/all.yml`:

```yaml
# GCP Configuration
gcp_project_id: "tu-proyecto-id"        # ← CAMBIAR ESTO
gcp_region: "us-central1"
gcp_zone: "us-central1-a"

# GKE Cluster
gke_cluster_name: "todoapp-autoscaling-cluster"
gke_cluster_version: "latest"

# Autoscaling
gke_node_pool:
  min_node_count: 2
  max_node_count: 10
  machine_type: "e2-standard-2"
```

---

## 🚀 Despliegue Completo con Ansible

### Paso 1: Clonar repositorio

```bash
git clone https://github.com/LeoUNSA/CloudComputing.git
cd CloudComputing/ToDoApp
```

### Paso 2: Editar configuración

```bash
# Editar variables (especialmente gcp_project_id)
nano ansible/inventories/gcp/group_vars/all.yml
```

### Paso 3: Desplegar infraestructura

```bash
# Despliegue completo (un solo comando)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml

# Con output verbose (recomendado para la primera vez)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml -v
```

### Paso 4: Verificar despliegue

```bash
# Obtener credenciales del cluster
gcloud container clusters get-credentials todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --project=tu-proyecto-id

# Ver pods
kubectl get pods -n todoapp

# Ver servicios y obtener IP externa
kubectl get svc -n todoapp

# Ver HPA
kubectl get hpa -n todoapp

# Ver nodos
kubectl get nodes
```

### Paso 5: Acceder a la aplicación

```bash
# Obtener IP externa
kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Acceder en el browser
# http://<EXTERNAL-IP>:3000
```

---

## 🔧 Estructura de Ansible

### Playbooks principales

```
ansible/
├── main.yml                 # Playbook de despliegue
├── cleanup.yml              # Playbook de limpieza
├── inventories/
│   └── gcp/
│       ├── hosts.yml        # Inventory (localhost)
│       └── group_vars/
│           └── all.yml      # Variables de configuración
└── tasks/
    ├── setup-gke-cluster.yml       # Crear GKE y networking
    ├── build-and-push-images.yml   # Construir/subir imágenes
    └── deploy-app.yml              # Desplegar app con Helm
```

### Variables configurables

Todas en `ansible/inventories/gcp/group_vars/all.yml`:

| Variable | Descripción | Default |
|----------|-------------|---------|
| `gcp_project_id` | ID del proyecto GCP | `todoapp-autoscaling-demo` |
| `gcp_region` | Región de GCP | `us-central1` |
| `gcp_zone` | Zona de GCP | `us-central1-a` |
| `gke_cluster_name` | Nombre del cluster | `todoapp-autoscaling-cluster` |
| `min_node_count` | Nodos mínimos | `2` |
| `max_node_count` | Nodos máximos | `10` |
| `machine_type` | Tipo de máquina | `e2-standard-2` |

### Personalizar el despliegue

```bash
# Cambiar proyecto por línea de comandos
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml \
  -e "gcp_project_id=mi-proyecto" \
  -e "gcp_region=europe-west1"

# Cambiar tamaño del cluster
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml \
  -e "gke_node_pool.min_node_count=3" \
  -e "gke_node_pool.max_node_count=20"
```

---

## 🧹 Limpieza de Recursos

### Destruir todo con Ansible

```bash
# Eliminar cluster, VPC, imágenes, todo
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml

# Sin confirmación (para CI/CD)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml \
  -e "confirm_user_input=yes"
```

### Verificar que no queden recursos

```bash
# Listar clusters
gcloud container clusters list --project=tu-proyecto-id

# Listar redes (excepto default)
gcloud compute networks list --project=tu-proyecto-id

# Listar discos
gcloud compute disks list --project=tu-proyecto-id
```

---

## 📦 Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| **IaC** | Ansible (playbooks, no Terraform) |
| **Cloud** | Google Cloud Platform (GKE) |
| **Orquestación** | Kubernetes 1.28+ |
| **Package Manager** | Helm 3 |
| **Backend** | Node.js + Express + PostgreSQL |
| **Frontend** | React + Nginx |
| **Autoscaling** | HPA v2 + GKE Cluster Autoscaler |
| **Container Registry** | Google Container Registry (GCR) |
| **CI/CD** | GitHub Actions |

---

## � Integración Continua (CI/CD)

El proyecto incluye **GitHub Actions workflows** para automatizar build, testing y deployment.

### Workflows Disponibles

| Workflow | Trigger | Descripción |
|----------|---------|-------------|
| **CI** | Push/PR a `main` o `develop` | Build, test, validación de manifiestos y security scan |
| **Deploy** | Push a `main` (o manual) | Despliegue completo a GKE con Ansible |
| **Cleanup** | Manual | Destrucción de toda la infraestructura GCP |

### Configuración Rápida

1. **Crear Service Account de GCP:**
   ```bash
   gcloud iam service-accounts create github-actions-deployer \
     --project=tu-proyecto-id
   
   # Otorgar permisos
   gcloud projects add-iam-policy-binding tu-proyecto-id \
     --member="serviceAccount:github-actions-deployer@tu-proyecto-id.iam.gserviceaccount.com" \
     --role="roles/container.admin"
   
   # (Repetir para: compute.admin, storage.admin, iam.serviceAccountUser)
   
   # Crear clave JSON
   gcloud iam service-accounts keys create ~/gcp-key.json \
     --iam-account=github-actions-deployer@tu-proyecto-id.iam.gserviceaccount.com
   ```

2. **Configurar GitHub Secret:**
   - Ve a: `https://github.com/LeoUNSA/CloudComputing/settings/secrets/actions`
   - Agrega `GCP_SA_KEY` con el contenido de `gcp-key.json`

3. **Ejecutar workflows:**
   ```bash
   # Ver workflows disponibles
   gh workflow list
   
   # Deploy manual
   gh workflow run "CD - Deploy to GCP"
   
   # Cleanup manual
   gh workflow run "Cleanup - Destroy GCP Resources" -f confirm=destroy
   
   # Ver estado
   gh run list
   ```

**📖 Guía completa:** [.github/SETUP.md](.github/SETUP.md)

---

## �🔧 Configuración de Autoscaling

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

## 🧪 Prueba de Autoscaling (Automatizado)

Hemos creado scripts automatizados para probar el autoscaling fácilmente:

### Opción 1: Test Completo Automatizado ⭐ (Recomendado)

Este script genera carga, monitorea el autoscaling y muestra estadísticas en tiempo real:

```bash
./load-testing/test-autoscaling.sh
```

**¿Qué hace?**
- ✅ Muestra estado inicial (pods, nodos, HPA)
- ✅ Crea 8 generadores de carga automáticamente
- ✅ Monitorea pods, nodos y HPA cada 10 segundos
- ✅ Muestra métricas en tiempo real con colores
- ✅ Detecta cuando se añaden pods y nodos
- ✅ Opción para limpiar generadores al final

**Personalizar:**
```bash
# Más carga = más pods/nodos
LOAD_GENERATORS=12 ./load-testing/test-autoscaling.sh

# Test más largo
TEST_DURATION=900 ./load-testing/test-autoscaling.sh  # 15 minutos
```

### Opción 2: Dashboard de Monitoreo

Para ver el estado en tiempo real (ejecuta en terminal separada):

```bash
./load-testing/monitor-autoscaling-dashboard.sh
```

**Características:**
- 📊 Dashboard visual con colores
- 🔄 Actualización cada 3 segundos
- 📈 Métricas de HPA (CPU, Memory)
- 🖥️ Estado de nodos
- 🔥 Detecta load generators activos

### Opción 3: Manual

```bash
# 1. Generar carga
for i in {1..8}; do
  kubectl run load-generator-$i --image=busybox --restart=Never -n todoapp \
    --labels="role=load-generator" \
    -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5001/stress?duration=30000; done"
done

# 2. Monitorear (terminal separada)
./load-testing/monitor-autoscaling-dashboard.sh

# 3. Limpiar
kubectl delete pod -n todoapp -l role=load-generator
```

### Comportamiento Esperado

```
T=0min:  🟢 Estado inicial
         - 2 pods backend, 2 nodos, CPU ~5%

T=0min:  🔴 Iniciar carga (8 generadores)
         
T=1min:  📈 HPA detecta CPU alto (>50%)
         - Backend: 2 → 4 pods
         
T=2-3min: 📈 HPA escala continuamente
         - Backend: 4 → 6 → 8 → 10 pods
         
T=4-5min: ⚠️  Pods "Pending"
         - 10 pods (máximo HPA)
         - No hay recursos en nodos

T=7min:  🖥️  Cluster Autoscaler añade nodo #3
         - Pods "Pending" → "Running"
         
──────────────────────────────────────────

T=X:     🔵 Detener carga
         
T+2min:  📉 HPA reduce gradualmente
         - 10 → 8 → 6 → 4 → 2 pods
         
T+10min: 🖥️  Cluster Autoscaler elimina nodos
         - Vuelve a 2 nodos (mínimo)
```

**📖 Más detalles:** `docs/05-MANUAL-AUTOSCALING-TEST.md`

**� Documentación detallada:** Ver `docs/05-MANUAL-AUTOSCALING-TEST.md`

---

## �📁 Estructura del Proyecto

```
ToDoApp/
├── ansible/                          # ⭐ Infrastructure as Code (lo importante)
│   ├── main.yml                      # Playbook de despliegue
│   ├── cleanup.yml                   # Playbook de limpieza
│   ├── inventories/gcp/
│   │   ├── hosts.yml                 # Inventory (localhost)
│   │   └── group_vars/
│   │       └── all.yml               # ⚙️ Variables de configuración
│   └── tasks/
│       ├── setup-gke-cluster.yml     # Crea GKE, VPC, subnet
│       ├── build-and-push-images.yml # Build/push a GCR
│       └── deploy-app.yml            # Deploy con Helm + HPA
│
├── .github/workflows/                # CI/CD con GitHub Actions
│   ├── ci.yml                        # Build/test automático
│   ├── deploy-gcp.yml                # Deploy con Ansible
│   └── cleanup-gcp.yml               # Cleanup de recursos
│
├── helm/todoapp/                     # Helm Chart de la aplicación
│   ├── values.yaml                   # Configuración
│   ├── values-dev.yaml               # Config para desarrollo
│   └── templates/
│       ├── hpa.yaml                  # Horizontal Pod Autoscaler
│       ├── backend-deployment.yaml
│       ├── frontend-deployment.yaml
│       └── postgres-deployment.yaml
│
├── backend/                          # API Node.js + Express
│   ├── server.js                     # Incluye endpoint /stress
│   ├── package.json
│   └── Dockerfile
│
├── frontend/                         # React SPA
│   ├── src/App.js
│   ├── nginx.conf                    # Reverse proxy a backend
│   └── Dockerfile
│
├── docs/                             # Documentación detallada
│   ├── 01-ANSIBLE-DEPLOYMENT.md
│   ├── 02-AUTOSCALING-MECHANISMS.md
│   ├── 05-MANUAL-AUTOSCALING-TEST.md
│   └── ...
│
├── load-testing/                     # Scripts de pruebas de carga
│   ├── simple-load-test.sh
│   ├── monitor-autoscaling.sh
│   └── extreme-load-test.sh
│
├── ANSIBLE-DEPLOYMENT.md             # 📖 Guía completa de Ansible
└── README.md                         # Este archivo
```

---

---

## � Documentación

- **[ANSIBLE-DEPLOYMENT.md](ANSIBLE-DEPLOYMENT.md)** - Guía completa de despliegue con Ansible
- **[.github/SETUP.md](.github/SETUP.md)** - Setup de GitHub Actions CI/CD
- **[docs/01-ANSIBLE-DEPLOYMENT.md](docs/01-ANSIBLE-DEPLOYMENT.md)** - Detalles técnicos de Ansible
- **[docs/02-AUTOSCALING-MECHANISMS.md](docs/02-AUTOSCALING-MECHANISMS.md)** - Cómo funciona el autoscaling
- **[docs/05-MANUAL-AUTOSCALING-TEST.md](docs/05-MANUAL-AUTOSCALING-TEST.md)** - Pruebas manuales de autoscaling

---

## 🚨 Troubleshooting

### Error: "Billing not enabled"
```bash
# Habilitar billing en: https://console.cloud.google.com/billing
gcloud billing projects link tu-proyecto-id --billing-account=BILLING_ID
```

### Error: "API not enabled"
```bash
# Ansible lo hace automáticamente, pero manualmente:
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
```

### Error: "Permission denied"
```bash
# Verificar autenticación
gcloud auth list
gcloud auth login
```

### Cluster no escala
```bash
# Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# Verificar HPA
kubectl describe hpa -n todoapp

# Ver eventos del cluster autoscaler
kubectl get events -n kube-system | grep cluster-autoscaler
```

---

## 💰 Gestión de Costos

### Estimación de costos (GCP us-central1)

| Recurso | Configuración | Costo/hora aprox. |
|---------|---------------|-------------------|
| GKE cluster | Gratis | $0.00 |
| 2 nodos e2-standard-2 | 2 vCPU, 8GB RAM cada uno | ~$0.13 |
| Load Balancer | 1 regla | ~$0.025 |
| Persistent Disk | 10GB SSD | ~$0.0002 |
| **Total** | **Mínimo** | **~$0.16/hora** |

**Costo diario mínimo:** ~$3.84  
**Costo mensual mínimo (24/7):** ~$115

### Reducir costos

```bash
# 1. Destruir cuando no uses (RECOMENDADO)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml

# 2. Reducir número de nodos mínimos
# Editar: ansible/inventories/gcp/group_vars/all.yml
gke_node_pool:
  min_node_count: 1  # En vez de 2
  max_node_count: 5
```

### Monitorear costos

```bash
# Ver gastos actuales
gcloud billing accounts list
gcloud billing projects describe tu-proyecto-id

# Configurar alertas: https://console.cloud.google.com/billing/alerts
```

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/amazing-feature`)
3. Commit tus cambios (`git commit -m 'Add amazing feature'`)
4. Push a la rama (`git push origin feature/amazing-feature`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está bajo la licencia MIT.

---

## ✨ Autor

**Leo** - [@LeoUNSA](https://github.com/LeoUNSA)

---

## � Agradecimientos

- Google Cloud Platform por la infraestructura
- Kubernetes por la orquestación
- Ansible por la automatización IaC
- Helm por el package management

---

## 📞 Soporte

¿Problemas con el despliegue? Abre un issue en GitHub:
https://github.com/LeoUNSA/CloudComputing/issues

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
