# Ansible Configuration for GCP GKE AutoScaling

Este directorio contiene los playbooks de Ansible para desplegar TodoApp en Google Kubernetes Engine (GKE) con AutoScaling completo.

## 📁 Estructura

```
ansible/
├── ansible.cfg                      # Configuración de Ansible
├── main.yml                         # Playbook principal (orquestador)
├── setup-gke-cluster.yml           # Crear cluster GKE
├── build-and-push-images.yml       # Build y push a GCR
├── deploy-app.yml                  # Deploy con Helm
├── cleanup.yml                     # Eliminar recursos
├── validate-setup.sh               # Script de validación
└── inventories/
    └── gcp/
        ├── hosts.yml               # Inventory
        └── group_vars/
            └── all.yml             # Variables de configuración
```

## 🚀 Uso Rápido

### Validar configuración
```bash
./validate-setup.sh
```

### Deployment completo
```bash
ansible-playbook main.yml
```

### Deployment por etapas
```bash
# Solo crear cluster
ansible-playbook setup-gke-cluster.yml

# Solo build de imágenes
ansible-playbook build-and-push-images.yml

# Solo deploy de app
ansible-playbook deploy-app.yml
```

### Usar tags
```bash
# Solo cluster
ansible-playbook main.yml --tags cluster

# Solo build
ansible-playbook main.yml --tags build

# Solo deploy
ansible-playbook main.yml --tags deploy
```

### Limpiar recursos
```bash
ansible-playbook cleanup.yml
```

## ⚙️ Configuración

### Variables de Entorno Requeridas

```bash
export GCP_PROJECT_ID="tu-proyecto-id"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"
```

### Personalizar Configuración

Edita `inventories/gcp/group_vars/all.yml`:

```yaml
# Proyecto GCP
gcp_project_id: "tu-proyecto-id"
gcp_region: "us-central1"
gcp_zone: "us-central1-a"

# Cluster
gke_cluster_name: "todoapp-autoscaling-cluster"

# Node Pool (Cluster Autoscaler)
gke_node_pool:
  initial_node_count: 2
  min_node_count: 2
  max_node_count: 10
  machine_type: "e2-standard-2"

# HPA Configuration
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

## 📋 Playbooks

### main.yml
Playbook orquestador que ejecuta todo el pipeline:
1. Setup del cluster GKE
2. Build y push de imágenes
3. Deploy de la aplicación

### setup-gke-cluster.yml
- Habilita APIs de GCP necesarias
- Crea VPC y subnet
- Crea cluster GKE con autoscaling habilitado
- Configura kubectl credentials
- Crea namespace de aplicación

### build-and-push-images.yml
- Configura Docker para GCR
- Build de imagen backend
- Build de imagen frontend
- Push de imágenes a Google Container Registry

### deploy-app.yml
- Instala metrics-server para HPA
- Crea archivo values personalizado
- Despliega app con Helm
- Espera a que los deployments estén listos
- Obtiene IP externa del LoadBalancer

### cleanup.yml
- Elimina Helm release
- Elimina namespace
- Elimina cluster GKE
- Elimina subnet y VPC
- Requiere confirmación interactiva

## 🔍 Validación

El script `validate-setup.sh` verifica:
- ✅ Herramientas instaladas (ansible, gcloud, kubectl, helm, docker)
- ✅ Variables de entorno configuradas
- ✅ Archivo de credenciales existe
- ✅ gcloud autenticado
- ✅ Proyecto configurado correctamente
- ✅ APIs de GCP habilitadas
- ✅ Estructura de directorios del proyecto
- ✅ Archivos críticos presentes

## 🛠️ Troubleshooting

### Error: "Could not authenticate"
```bash
gcloud auth activate-service-account --key-file=$GCP_CREDENTIALS_FILE
gcloud config set project $GCP_PROJECT_ID
```

### Error: "API not enabled"
Las APIs se habilitan automáticamente durante el deployment. Si falla:
```bash
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

### Error: "Quota exceeded"
Verifica tus cuotas en GCP Console:
- https://console.cloud.google.com/iam-admin/quotas

### Playbook se cuelga
- Verifica conectividad a internet
- Asegúrate de que gcloud está autenticado
- Revisa los logs: `ansible-playbook main.yml -vv`

## 📊 Monitoreo Post-Deployment

```bash
# Ver estado del cluster
kubectl cluster-info
kubectl get nodes

# Ver pods y HPAs
kubectl get all -n todoapp
kubectl get hpa -n todoapp -w

# Ver métricas
kubectl top nodes
kubectl top pods -n todoapp

# Ver eventos
kubectl get events -n todoapp --sort-by='.lastTimestamp'
```

## 💰 Costos

- **Setup inicial**: ~15-20 minutos
- **Costo mínimo**: ~$0.35/hora (2 nodos)
- **Costo máximo**: ~$1.75/hora (10 nodos)

⚠️ **IMPORTANTE**: Ejecuta `ansible-playbook cleanup.yml` cuando termines para evitar cargos.

## 🔗 Referencias

- [Ansible GCP Modules](https://docs.ansible.com/ansible/latest/collections/google/cloud/)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cluster Autoscaler](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler)
