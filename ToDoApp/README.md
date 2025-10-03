# 📝 TodoApp - Gestor de Tareas Cloud Native en Kubernetes

## 📖 Descripción

**TodoApp** es una aplicación web moderna de gestión de tareas desarrollada con arquitectura de microservicios, desplegada completamente en **Kubernetes usando Kind**. La aplicación permite a los usuarios crear, gestionar, completar y eliminar tareas de manera eficiente, proporcionando una interfaz web intuitiva respaldada por una API REST robusta y una base de datos PostgreSQL persistente.

La aplicación está diseñada siguiendo las mejores prácticas de **Cloud Native** y **DevOps**, utilizando contenedores Docker orquestados por Kubernetes, gestión declarativa con Helm, y observabilidad completa con Prometheus y Grafana.

### 🎯 Características Cloud Native

- ✅ **Arquitectura Cloud Native**: Microservicios en Kubernetes con alta disponibilidad
- ✅ **Interfaz moderna**: Frontend React optimizado servido por Nginx
- ✅ **API REST robusta**: Backend Node.js/Express con health checks y métricas
- ✅ **Persistencia garantizada**: PostgreSQL con PersistentVolumes de Kubernetes
- ✅ **Orquestación profesional**: Despliegue declarativo con Helm Charts
- ✅ **Observabilidad completa**: Monitoreo en tiempo real con Prometheus y Grafana
- ✅ **Alta disponibilidad**: Múltiples réplicas con load balancing automático
- ✅ **Autorecuperación**: Self-healing y rolling updates sin downtime
- ✅ **Escalabilidad horizontal**: HPA (Horizontal Pod Autoscaling) configurado
- ✅ **Gestión de configuración**: ConfigMaps y Secrets de Kubernetes
- ✅ **Service Discovery**: Comunicación automática entre microservicios
- ✅ **Tolerancia a fallos**: Circuit breakers y retry mechanisms

### 🔧 Stack Tecnológico

| Componente | Tecnología | Versión | Propósito |
|------------|------------|---------|-----------|
| **Orquestación** | Kubernetes (Kind) | v1.34.0 | Gestión de contenedores y servicios |
| **Gestión de Apps** | Helm | v3.x | Despliegues declarativos y templating |
| **Frontend** | React + Nginx | 18.2.0 + Alpine | Interfaz de usuario responsiva |
| **Backend** | Node.js + Express | 18.x | API REST y lógica de negocio |
| **Base de Datos** | PostgreSQL | 15 Alpine | Persistencia de datos transaccional |
| **Monitoreo** | Prometheus + Grafana | Latest | Observabilidad y alertas |
| **Contenedores** | Docker | 28.x | Empaquetado de aplicaciones |
| **Storage** | Local Path Provisioner | Latest | Volúmenes persistentes |

### 🌐 Endpoints de Acceso

| Servicio | URL | Credenciales | Descripción |
|----------|-----|--------------|-------------|
| **Frontend Web** | http://localhost:30000 | - | Interfaz principal de usuario |
| **API REST** | http://localhost:30001 | - | Endpoints de backend |
| **Health Check** | http://localhost:30001/health | - | Estado del backend |
| **Grafana** | http://localhost:30002 | admin/admin123 | Dashboards de monitoreo |
| **Prometheus** | http://localhost:9091 | - | Métricas y alertas |

---

## 🏗️ Arquitectura de Microservicios en Kubernetes

TodoApp está implementada usando principios de microservicios en Kubernetes, garantizando escalabilidad, mantenibilidad y tolerancia a fallos.

### 🎯 Frontend Service (React + Nginx)

**Tecnología**: React 18 + Nginx Alpine
```yaml
Namespace: todoapp
Deployment: todoapp-frontend
Réplicas: 2 (Alta Disponibilidad)
Recursos: 100m CPU, 128Mi RAM por réplica
Service: ClusterIP + NodePort 30000
```

**Características Kubernetes**:
- 🔄 **Rolling Updates**: Actualizaciones sin downtime
- ⚖️ **Load Balancing**: Tráfico distribuido automáticamente por Kubernetes Service
- 🛡️ **Health Checks**: Liveness y Readiness probes configurados
- 🔄 **Self-Healing**: Pods recreados automáticamente si fallan
- 📊 **HPA Ready**: Escalado horizontal basado en CPU
- 🏷️ **Labels & Selectors**: Gestión declarativa con etiquetas Kubernetes

**Configuración Kubernetes**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todoapp-frontend
  namespace: todoapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todoapp-frontend
  template:
    spec:
      containers:
      - name: frontend
        image: todoapp-frontend:latest
        ports:
        - containerPort: 3000
        livenessProbe:
          httpGet:
            path: /
            port: 3000
        readinessProbe:
          httpGet:
            path: /
            port: 3000
```

### 🔧 Backend Service (Node.js/Express)

**Tecnología**: Node.js 18 + Express
```yaml
Namespace: todoapp
Deployment: todoapp-backend
Réplicas: 2 (Balanceador de carga)
Recursos: 200m CPU, 256Mi RAM por réplica
Service: ClusterIP + NodePort 30001
ConfigMap: Backend configuration
Secret: Database credentials
```

**Características Kubernetes**:
- 🔐 **ConfigMaps**: Configuración externalizada y versionada
- 🔑 **Secrets**: Credenciales de BD almacenadas de forma segura
- 📡 **Service Discovery**: Comunicación automática con PostgreSQL
- 📊 **Metrics Endpoint**: Exposición de métricas para Prometheus
- 🔄 **Connection Pooling**: Pool de conexiones optimizado para contenedores
- 🛡️ **Security Context**: Contenedor ejecutado con usuario no-root

**Endpoints API**:
```javascript
GET    /tasks           // Obtener todas las tareas
POST   /tasks           // Crear nueva tarea
PUT    /tasks/:id       // Actualizar tarea existente
DELETE /tasks/:id       // Eliminar tarea
GET    /health          // Health check para Kubernetes
GET    /metrics         // Métricas para Prometheus
```

### 🗄️ Database Service (PostgreSQL)

**Tecnología**: PostgreSQL 15 Alpine
```yaml
Namespace: todoapp
Deployment: todoapp-postgres
Réplicas: 1 (StatefulSet pattern)
Recursos: 500m CPU, 512Mi RAM
PVC: 1Gi PersistentVolumeClaim
ConfigMap: Init SQL scripts
Secret: Database credentials
```

**Características Kubernetes**:
- 💾 **PersistentVolumes**: Datos persistentes con reclaim policy
- 🔄 **Init Containers**: Inicialización automática de esquema
- 📊 **Health Checks**: Verificación con pg_isready
- 🔐 **Network Policies**: Acceso restringido solo desde backend
- 📈 **Resource Limits**: CPU y memoria garantizados
- 🔄 **Backup Ready**: Scripts de backup integrados

**Esquema de Base de Datos**:
```sql
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 📊 Monitoring Stack (Prometheus + Grafana)

**Tecnología**: Prometheus Operator + Grafana
```yaml
Namespace: monitoring
Componentes: 8 pods especializados
- prometheus-server: Time-series database
- grafana: Dashboard visualization
- alertmanager: Alert management
- node-exporter: Host metrics (3 pods)
- kube-state-metrics: Kubernetes metrics
- prometheus-operator: CRD management
```

**Características Kubernetes**:
- 📈 **Custom Resources**: ServiceMonitor, PrometheusRule, AlertmanagerConfig
- 🎯 **Service Discovery**: Auto-discovery de targets en Kubernetes
- 📊 **PersistentVolumes**: 5Gi para métricas, 1Gi para Grafana
- 🔔 **AlertManager**: Gestión de alertas con routing y silencing
- 📋 **Dashboards**: Pre-configurados para Kubernetes y aplicación
- 🔄 **High Availability**: Múltiples réplicas con sharding

---

## 🎯 Kubernetes (Kind) - ¿Por qué y cómo?

### 🔍 ¿Por qué Kind para este proyecto?

**Kind (Kubernetes in Docker)** es la herramienta perfecta para este proyecto porque:

✅ **Desarrollo Local Optimizado**
- Cluster Kubernetes **100% real** corriendo en Docker
- Startup rápido: **<2 minutos** vs minikube (~5 minutos)
- Recursos optimizados: usa solo los recursos necesarios
- **Reproducibilidad**: mismo entorno en cualquier máquina

✅ **Fidelidad con Producción**
- **API idéntica** a Kubernetes real (EKS, GKE, AKS)
- Mismos manifiestos YAML funcionan en prod
- **Networking real**: CNI, Services, Ingress funcionan igual
- **Storage real**: PersistentVolumes con Local Path Provisioner

✅ **CI/CD Ready**
- Ideal para **testing automático** en pipelines
- **GitHub Actions**, GitLab CI/CD compatible
- **Multi-node clusters** para testing de HA
- **Ephemeral clusters** para testing aislado

### 🏗️ Configuración del Cluster Kind

**Archivo**: `k8s/kind-config.yaml`
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: todoapp-cluster
nodes:
- role: control-plane          # Master node
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:           # Port forwarding hacia host
  - containerPort: 30000       # Frontend
    hostPort: 30000
  - containerPort: 30001       # Backend
    hostPort: 30001
  - containerPort: 30002       # Grafana
    hostPort: 30002
- role: worker                 # Worker node 1
- role: worker                 # Worker node 2
```

### 🔧 Características del Cluster

**Topología**:
- **1 Control Plane**: API Server, etcd, Scheduler, Controller Manager
- **2 Worker Nodes**: Para simular entorno de producción multi-nodo
- **3 Nodos totales**: Permite testing de scheduling, affinity, tolerations

**Networking**:
- **CNI**: Kindnet (networking plugin optimizado)
- **Service Types**: ClusterIP, NodePort, LoadBalancer (MetalLB opcional)
- **Port Mapping**: Acceso directo desde host a servicios
- **DNS**: CoreDNS para service discovery interno

**Storage**:
- **Local Path Provisioner**: PersistentVolumes dinámicos
- **Storage Classes**: default, local-path
- **Volume Types**: hostPath, emptyDir, configMap, secret

### 🚀 Ventajas sobre Alternativas

| Característica | Kind | Minikube | Docker Compose |
|----------------|------|----------|----------------|
| **API Kubernetes** | ✅ 100% Real | ✅ Real | ❌ No |
| **Multi-node** | ✅ Sí | ❌ Solo single-node | ❌ No |
| **Startup Time** | ✅ <2 min | ⚠️ ~5 min | ✅ <1 min |
| **Resource Usage** | ✅ Optimizado | ⚠️ Alto | ✅ Bajo |
| **Production Parity** | ✅ 100% | ✅ 95% | ❌ 60% |
| **CI/CD Integration** | ✅ Excelente | ⚠️ Bueno | ❌ Limitado |
| **Learning Curve** | ⚠️ Medio | ⚠️ Medio | ✅ Bajo |

### 🎛️ Gestión del Cluster Kind

**Comandos esenciales**:
```bash
# Crear cluster con configuración
kind create cluster --config=k8s/kind-config.yaml

# Ver clusters disponibles
kind get clusters

# Obtener kubeconfig
kind get kubeconfig --name todoapp-cluster

# Cargar imágenes Docker
kind load docker-image todoapp-frontend:latest --name todoapp-cluster

# Eliminar cluster
kind delete cluster --name todoapp-cluster
```

**Troubleshooting común**:
```bash
# Verificar nodos
kubectl get nodes
kubectl describe node todoapp-cluster-worker

# Ver pods del sistema
kubectl get pods -n kube-system

# Logs del cluster
docker logs todoapp-cluster-control-plane
```

---

## 🛠️ Justificación de Herramientas Usadas

### 🎯 Kubernetes Kind - Orquestación Local

**¿Por qué Kind?**

✅ **Desarrollo Local Optimizado**
- Cluster Kubernetes completo en Docker
- Configuración reproducible y versionada
- Aislamiento perfecto del sistema host
- Startup rápido (<2 minutos) vs minikube (~5 minutos)

✅ **Fidelidad con Producción**
- API 100% compatible con Kubernetes real
- Mismos manifiestos para dev/staging/prod
- Testing de comportamiento de red real
- Validación de resource limits y requests

✅ **Facilidad de Gestión**
```bash
# Cluster completo en un comando
kind create cluster --config=k8s/kind-config.yaml

# Cargar imágenes locales
kind load docker-image todoapp-frontend:latest
```

**Configuración Optimizada**:
```yaml
# 3 nodos: 1 control-plane + 2 workers
# Port mappings para acceso directo
# Networking configurado para desarrollo
extraPortMappings:
  - containerPort: 30000  # Frontend
  - containerPort: 30001  # Backend  
  - containerPort: 30002  # Grafana
```

### 📊 Prometheus - Observabilidad Empresarial

**¿Por qué Prometheus?**

✅ **Estándar de la Industria**
- Adoptado por CNCF (Cloud Native Computing Foundation)
- Usado por Google, AWS, Netflix, Uber
- Ecosistema maduro con 1000+ exporters
- Integración nativa con Kubernetes

✅ **Modelo de Datos Potente**
```promql
# Consultas complejas con PromQL
rate(http_requests_total{service="todoapp"}[5m])

# Alertas basadas en tendencias
increase(container_restarts[1h]) > 3
```

✅ **Escalabilidad y Rendimiento**
- Time-series database optimizado
- Compresión eficiente (10:1 ratio típico)
- Federación para clusters múltiples
- Retention policies configurables

✅ **Integración Kubernetes Nativa**
- Service Discovery automático
- Métricas de pods/nodes/services automáticas
- Labels de Kubernetes como dimensiones
- Operator pattern para gestión declarativa

**Métricas Recopiladas**:
```yaml
Infraestructura: CPU, memoria, red, disco
Aplicación: Requests/seg, latencia, errores
Kubernetes: Pod status, deployments, events
Negocio: Tareas creadas, usuarios activos
```

### 📦 Helm - Gestión de Aplicaciones

**¿Por qué Helm?**

✅ **Gestión Declarativa Avanzada**
```bash
# Despliegue parametrizable
helm install todoapp ./helm/todoapp \
  --set replicaCount.backend=5 \
  --set monitoring.enabled=true
```

✅ **Templating Potente**
- Variables centralizadas en `values.yaml`
- Condicionales y loops en templates
- Funciones helper reutilizables
- Validación de esquemas

✅ **Gestión de Ciclo de Vida**
```bash
helm upgrade todoapp ./helm/todoapp    # Actualización
helm rollback todoapp 1               # Rollback seguro
helm uninstall todoapp                # Limpieza completa
```

✅ **Entornos Múltiples**
```yaml
# values-dev.yaml
replicaCount:
  backend: 1
monitoring:
  enabled: false

# values-prod.yaml  
replicaCount:
  backend: 5
monitoring:
  enabled: true
```

**Estructura del Chart**:
```
helm/todoapp/
├── Chart.yaml          # Metadatos del chart
├── values.yaml         # Configuración predeterminada
├── values-dev.yaml     # Configuración desarrollo
└── templates/          # Templates Kubernetes
    ├── deployment.yaml # Deployments parametrizables
    ├── service.yaml    # Services con configuración
    ├── configmap.yaml  # ConfigMaps templated
    └── pvc.yaml        # Storage persistente
```

### 🔄 Beneficios de la Combinación

**Kind + Prometheus + Helm = Plataforma Completa**

1. **Desarrollo**: Kind proporciona entorno idéntico a producción
2. **Despliegue**: Helm simplifica gestión de configuraciones complejas
3. **Operación**: Prometheus ofrece observabilidad total
4. **Escalado**: Kubernetes maneja crecimiento automático

**Pipeline DevOps Habilitado**:
```bash
# CI/CD Ready
git push → Docker build → Helm upgrade → Prometheus alerts
```

**Costos Optimizados**:
- Kind: Desarrollo local sin costos cloud
- Prometheus: Monitoreo sin herramientas SaaS caras
- Helm: Reutilización de configuraciones
- Kubernetes: Optimización automática de recursos

---

## 🚀 Comandos de Inicio Rápido

### ⚡ **INICIAR TODO (Comando Principal)**
```bash
# 🎯 Despliegue completo automático
make full-deploy
```

### 📊 **VERIFICAR ESTADO**
```bash
# Estado general
make status

# Validación completa
./scripts/validate.sh

# Ver logs
make logs
```

### 🌐 **ACCEDER A LA APLICACIÓN**
- **Frontend**: http://localhost:30000
- **Backend API**: http://localhost:30001  
- **Grafana**: http://localhost:30002 (admin/admin123)
- **Prometheus**: http://localhost:9091

### 🛑 **GESTIÓN DE DATOS**
```bash
# Parar manteniendo datos (RECOMENDADO)
make soft-stop

# Crear backup antes de limpiar
make backup

# Limpiar todo (ELIMINA DATOS)
make clean
```

> 📋 **Guía completa de comandos**: Ver [`COMANDOS.md`](COMANDOS.md) para comandos detallados, troubleshooting y mejores prácticas.

## 📊 Arquitectura de Despliegue en Kubernetes

```
┌─────────────────────────────────────────────────────────────┐
│                    Kind Cluster                             │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │
│  │ Control Plane │  │   Worker 1    │  │   Worker 2    │   │
│  │               │  │               │  │               │   │
│  │ - API Server  │  │ - Frontend    │  │ - Backend     │   │
│  │ - etcd        │  │ - Postgres    │  │ - Prometheus  │   │
│  │ - Scheduler   │  │ - Grafana     │  │ - Node Exp.   │   │
│  │ - Controller  │  │ - Node Exp.   │  │               │   │
│  └───────────────┘  └───────────────┘  └───────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────────────┐
                    │   Host Machine  │
                    │                 │
                    │ Port Mappings:  │
                    │ :30000 → Frontend│
                    │ :30001 → Backend │
                    │ :30002 → Grafana │
                    └─────────────────┘
```

## 🔍 Observabilidad y Monitoreo

### 📈 **Métricas Disponibles**

**Infraestructura (automáticas)**:
- CPU, memoria, disco por pod/nodo
- Tráfico de red y I/O
- Estado de pods y deployments
- Eventos de Kubernetes

**Aplicación (configuradas)**:
- Requests HTTP por endpoint
- Latencia de respuesta (P50, P95, P99)
- Códigos de estado HTTP
- Errores y excepciones

**Negocio (personalizables)**:
- Tareas creadas/completadas
- Usuarios activos
- Tiempo de sesión
- Patrones de uso

### 🎨 **Dashboards Grafana**

- **Kubernetes Overview**: Estado general del cluster
- **Pod Monitoring**: Métricas específicas de TodoApp
- **Node Metrics**: Rendimiento de nodos
- **Application Metrics**: KPIs de negocio

### 🚨 **Alertas Configuradas**

- Pod no disponible > 1 minuto
- CPU > 80% por 5 minutos
- Memoria > 90%
- Errores HTTP > 5% en 10 minutos
- Base de datos no disponible
