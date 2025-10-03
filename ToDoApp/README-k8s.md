# TodoApp - Migración a Kubernetes

Este proyecto ha sido migrado de Docker Compose a Kubernetes usando Kind, con Helm para la gestión de despliegues y Prometheus para monitoreo.

## 📋 Prerrequisitos

Antes de comenzar, asegúrate de tener instalados:

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)

### Instalación rápida de herramientas (Ubuntu/Debian):

```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## 🚀 Despliegue Rápido

### 1. Configuración inicial

```bash
# Configurar Kind y construir imágenes
./scripts/setup.sh
```

### 2. Desplegar la aplicación

```bash
# Desplegar con Helm
./scripts/deploy.sh
```

### 3. Instalar Prometheus (Opcional)

```bash
# Instalar stack de Prometheus y Grafana
./scripts/install-prometheus.sh
```

## 🌐 Acceso a la Aplicación

Después del despliegue:

- **Frontend**: http://localhost:30000
- **Backend API**: http://localhost:30001
- **Grafana** (si está instalado): http://localhost:30002 (admin/admin123)

## 📁 Estructura del Proyecto

```
ToDoApp/
├── k8s/                          # Manifiestos de Kubernetes
│   ├── kind-config.yaml         # Configuración del cluster Kind
│   └── manifests/               # Manifiestos YAML nativos
├── helm/                        # Charts de Helm
│   └── todoapp/                # Chart principal de la aplicación
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── monitoring/                  # Configuración de Prometheus
│   ├── prometheus-namespace.yaml
│   └── prometheus-values.yaml
├── scripts/                     # Scripts de automatización
│   ├── setup.sh               # Configuración inicial
│   ├── deploy.sh              # Despliegue de la aplicación
│   ├── install-prometheus.sh  # Instalación de Prometheus
│   └── cleanup.sh             # Limpieza de recursos
└── README-k8s.md              # Esta documentación
```

## 🔧 Comandos Útiles

### Gestión del Cluster

```bash
# Ver estado del cluster
kubectl cluster-info --context kind-todoapp-cluster

# Ver todos los recursos
kubectl get all -n todoapp

# Ver logs de los pods
kubectl logs -l app.kubernetes.io/component=backend -n todoapp
kubectl logs -l app.kubernetes.io/component=frontend -n todoapp
kubectl logs -l app.kubernetes.io/component=postgres -n todoapp
```

### Gestión con Helm

```bash
# Ver releases instalados
helm list -n todoapp

# Ver valores de configuración
helm get values todoapp -n todoapp

# Actualizar la aplicación
helm upgrade todoapp ./helm/todoapp -n todoapp

# Desinstalar la aplicación
helm uninstall todoapp -n todoapp
```

### Monitoreo

```bash
# Acceder a Prometheus UI
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring

# Acceder a AlertManager
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring

# Ver estado del monitoreo
kubectl get all -n monitoring
```

## 🎛️ Configuración

### Valores de Helm

Puedes personalizar el despliegue modificando `helm/todoapp/values.yaml`:

```yaml
# Cambiar número de réplicas
replicaCount:
  backend: 3
  frontend: 3

# Modificar recursos
resources:
  backend:
    limits:
      cpu: 500m
      memory: 512Mi
```

### Variables de Entorno

Las variables se configuran en los ConfigMaps y Secrets generados por Helm.

## 📊 Monitoreo y Métricas

### Prometheus

Prometheus está configurado para:
- Recopilar métricas de todos los pods
- Almacenar métricas por 7 días
- Enviar alertas configurables

### Grafana

Grafana incluye:
- Dashboard predeterminado de Kubernetes
- Métricas de la aplicación TodoApp
- Alertas visuales configurables

### ServiceMonitors

Se han configurado ServiceMonitors para:
- Backend API (endpoint `/metrics`)
- Métricas de sistema de Kubernetes

## 🔒 Seguridad

### Secrets

Las contraseñas se almacenan en Kubernetes Secrets:
- `postgres-secret`: Contraseña de la base de datos
- `backend-secret`: Variables sensibles del backend

### RBAC

Se utiliza un ServiceAccount dedicado con permisos mínimos.

## 💾 Persistencia

### Volúmenes

- **PostgreSQL**: PersistentVolumeClaim de 1Gi
- **Prometheus**: PersistentVolumeClaim de 5Gi
- **Grafana**: PersistentVolumeClaim de 1Gi

## 🚨 Troubleshooting

### Problemas Comunes

1. **Pods en estado Pending**:
   ```bash
   kubectl describe pod <pod-name> -n todoapp
   ```

2. **Imágenes no encontradas**:
   ```bash
   # Volver a cargar las imágenes
   kind load docker-image todoapp-backend:latest --name todoapp-cluster
   kind load docker-image todoapp-frontend:latest --name todoapp-cluster
   ```

3. **Base de datos no conecta**:
   ```bash
   # Verificar que PostgreSQL esté corriendo
   kubectl get pods -l app.kubernetes.io/component=postgres -n todoapp
   ```

### Logs de Troubleshooting

```bash
# Ver eventos del cluster
kubectl get events -n todoapp --sort-by='.lastTimestamp'

# Verificar recursos
kubectl top pods -n todoapp
kubectl top nodes
```

## 🧹 Limpieza

Para eliminar todos los recursos:

```bash
./scripts/cleanup.sh
```

Esto eliminará:
- El release de Helm de TodoApp
- El stack de Prometheus
- Los namespaces `todoapp` y `monitoring`
- El cluster de Kind completo

## 📈 Escalado

### Escalado Manual

```bash
# Escalar backend
kubectl scale deployment todoapp-backend --replicas=5 -n todoapp

# Escalar frontend
kubectl scale deployment todoapp-frontend --replicas=3 -n todoapp
```

### Autoescalado (HPA)

Habilita el autoescalado en `values.yaml`:

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

## 🔄 CI/CD

Este setup está preparado para integración con CI/CD:

1. **Build**: `docker build` en CI
2. **Push**: `kind load docker-image` o push a registry
3. **Deploy**: `helm upgrade` con nuevos valores

## 📞 Soporte

Para problemas o preguntas:
1. Revisar logs: `kubectl logs`
2. Verificar eventos: `kubectl get events`
3. Comprobar recursos: `kubectl get all`
4. Consultar documentación de [Kubernetes](https://kubernetes.io/docs/) y [Helm](https://helm.sh/docs/)