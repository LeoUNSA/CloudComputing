# Quick Start Guide - GCP AutoScaling

## Setup Rápido (5 minutos)

### 1. Prerequisitos
```bash
# Instalar herramientas
sudo apt update
sudo apt install -y ansible
curl https://sdk.cloud.google.com | bash
gcloud init

# Configurar proyecto
export GCP_PROJECT_ID="tu-proyecto-id"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"
```

### 2. Crear Service Account
```bash
# Crear y configurar service account
gcloud iam service-accounts create todoapp-deployer
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.admin"
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
    --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/compute.admin"
    
# Descargar credenciales
mkdir -p ~/.gcp
gcloud iam service-accounts keys create ~/.gcp/credentials.json \
    --iam-account=todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

### 3. Configurar Variables
```bash
# Editar configuración
cd ansible
vim inventories/gcp/group_vars/all.yml

# Cambiar:
# gcp_project_id: "TU_PROYECTO_ID"
```

### 4. Desplegar
```bash
# Deployment completo
ansible-playbook main.yml

# Espera ~15-20 minutos
```

### 5. Acceder
```bash
# Obtener URL
kubectl get svc todoapp-frontend -n todoapp

# Abrir en navegador:
# http://<EXTERNAL-IP>:3000
```

### 6. Probar AutoScaling
```bash
# Terminal 1: Monitor
cd ../load-testing
./monitor-autoscaling.sh

# Terminal 2: Generar carga
./simple-load-test.sh
```

### 7. Limpiar
```bash
cd ../ansible
ansible-playbook cleanup.yml
```

## Comandos Útiles

```bash
# Ver estado de HPA
kubectl get hpa -n todoapp -w

# Ver pods
kubectl get pods -n todoapp -o wide

# Ver nodos
kubectl get nodes

# Ver métricas
kubectl top pods -n todoapp
kubectl top nodes

# Logs backend
kubectl logs -n todoapp -l app.kubernetes.io/component=backend

# Escalar manualmente (temporalmente)
kubectl scale deployment todoapp-backend -n todoapp --replicas=5
```

## Troubleshooting Rápido

### HPA muestra <unknown>
```bash
# Reinstalar metrics-server
helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args[0]="--kubelet-insecure-tls"
    
# Esperar 2 minutos
```

### No obtiene IP externa
```bash
# Esperar 3-5 minutos
# Si persiste, verificar:
kubectl describe svc todoapp-frontend -n todoapp
```

### Pods Pending
```bash
# Ver por qué
kubectl describe pod <pod-name> -n todoapp

# Verificar nodos
kubectl get nodes
kubectl describe nodes
```

## Estructura del Proyecto

```
ansible/
├── main.yml                    # Playbook principal
├── setup-gke-cluster.yml       # Crear cluster
├── build-and-push-images.yml   # Build imágenes
├── deploy-app.yml              # Deploy app
├── cleanup.yml                 # Limpiar recursos
└── inventories/gcp/
    └── group_vars/all.yml      # Variables de configuración

load-testing/
├── monitor-autoscaling.sh      # Monitor en tiempo real
├── simple-load-test.sh         # Test básico
├── run-load-test.sh            # Test avanzado
└── extreme-load-test.sh        # Test extremo

helm/todoapp/
├── values.yaml                 # Configuración base
└── templates/
    ├── hpa.yaml               # HPA definitions
    ├── backend-deployment.yaml
    └── frontend-deployment.yaml
```

## Métricas de AutoScaling

| Componente | Min | Max | CPU Target | Mem Target |
|------------|-----|-----|------------|------------|
| Backend | 2 | 10 | 50% | 70% |
| Frontend | 2 | 8 | 60% | 75% |
| Nodos | 2 | 10 | - | - |

## Costos Estimados

- **Mínimo (2 nodos)**: ~$8/día
- **Máximo (10 nodos)**: ~$42/día
- **Prueba de 1 hora**: ~$0.35-$1.75

⚠️ **IMPORTANTE**: Siempre ejecuta cleanup al terminar!
