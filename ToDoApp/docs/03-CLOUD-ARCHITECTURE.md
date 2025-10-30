# Arquitectura Cloud y Componentes de Red

## Índice
1. [Visión General de la Arquitectura](#visión-general-de-la-arquitectura)
2. [Componentes de GCP](#componentes-de-gcp)
3. [Networking en Kubernetes](#networking-en-kubernetes)
4. [Load Balancer](#load-balancer)
5. [Nginx como Reverse Proxy](#nginx-como-reverse-proxy)
6. [Flujo de Tráfico Completo](#flujo-de-tráfico-completo)
7. [Seguridad y Aislamiento](#seguridad-y-aislamiento)

---

## Visión General de la Arquitectura

### Diagrama de Arquitectura Completa

```
                                    INTERNET
                                       │
                                       │
                ┌──────────────────────▼──────────────────────┐
                │         GCP Load Balancer                   │
                │    External IP: 34.42.115.79                │
                │    Type: LoadBalancer (L4)                  │
                └──────────────────────┬──────────────────────┘
                                       │
                                       │ Port 3000
                                       │
┌──────────────────────────────────────┼──────────────────────────────────────┐
│  GKE CLUSTER: todoapp-autoscaling-cluster                                   │
│  Region: us-central1-a                                                      │
│                                      │                                       │
│      ┌───────────────────────────────▼─────────────────────────┐            │
│      │  Service: todoapp-frontend (LoadBalancer)               │            │
│      │  ClusterIP: 10.xx.xx.xx                                 │            │
│      │  External: 34.42.115.79:3000                            │            │
│      └───────────────────────────────┬─────────────────────────┘            │
│                                      │                                       │
│                  ┌───────────────────┴───────────────────┐                  │
│                  │                                       │                  │
│         ┌────────▼────────┐                   ┌──────────▼─────────┐        │
│         │  Frontend Pod 1  │                   │  Frontend Pod 2    │        │
│         │  ┌────────────┐  │                   │  ┌────────────┐    │        │
│         │  │   Nginx    │  │                   │  │   Nginx    │    │        │
│         │  │ Port: 3000 │  │                   │  │ Port: 3000 │    │        │
│         │  └──────┬─────┘  │                   │  └──────┬─────┘    │        │
│         │         │/api/   │                   │         │/api/     │        │
│         │  ┌──────▼─────┐  │                   │  ┌──────▼─────┐    │        │
│         │  │React App   │  │                   │  │React App   │    │        │
│         │  │Port: 3000  │  │                   │  │Port: 3000  │    │        │
│         │  └────────────┘  │                   │  └────────────┘    │        │
│         └────────┬──────────┘                   └────────┬──────────┘        │
│                  │                                       │                   │
│                  │  HTTP Request: /api/tasks             │                   │
│                  │  Proxy to: todoapp-backend:5000/tasks │                   │
│                  │                                       │                   │
│                  └────────────────┬──────────────────────┘                   │
│                                   │                                          │
│      ┌────────────────────────────▼──────────────────────────┐               │
│      │  Service: todoapp-backend (ClusterIP)                 │               │
│      │  ClusterIP: 10.xx.yy.yy                               │               │
│      │  Port: 5000 (solo interno)                            │               │
│      └────────────────────────────┬──────────────────────────┘               │
│                                   │                                          │
│       ┌───────────────────────────┼───────────────────┐                      │
│       │                           │                   │                      │
│  ┌────▼─────┐            ┌────────▼────┐      ┌──────▼──────┐               │
│  │Backend   │            │Backend      │      │Backend      │  (2-10 pods)  │
│  │Pod 1     │            │Pod 2        │ ...  │Pod N        │  HPA          │
│  │Node.js   │            │Node.js      │      │Node.js      │               │
│  │Port: 5000│            │Port: 5000   │      │Port: 5000   │               │
│  └────┬─────┘            └────────┬────┘      └──────┬──────┘               │
│       │                           │                   │                      │
│       │         PostgreSQL Query: SELECT * FROM tasks │                      │
│       │                           │                   │                      │
│       └───────────────────────────┼───────────────────┘                      │
│                                   │                                          │
│      ┌────────────────────────────▼──────────────────────────┐               │
│      │  Service: todoapp-postgres (ClusterIP)                │               │
│      │  ClusterIP: 10.xx.zz.zz                               │               │
│      │  Port: 5432 (solo interno)                            │               │
│      └────────────────────────────┬──────────────────────────┘               │
│                                   │                                          │
│                          ┌────────▼────────┐                                 │
│                          │ PostgreSQL Pod  │                                 │
│                          │ Port: 5432      │                                 │
│                          │ ┌────────────┐  │                                 │
│                          │ │ PVC: 10Gi  │  │                                 │
│                          │ │ GCE PD     │  │                                 │
│                          │ └────────────┘  │                                 │
│                          └─────────────────┘                                 │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│  VPC Network: todoapp-network                                                │
│  Subnet: todoapp-subnet (10.0.0.0/24)                                        │
│  Region: us-central1                                                         │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Componentes de GCP

### 1. VPC Network (Virtual Private Cloud)

**Definición**: Red privada virtual aislada en GCP.

**Configuración en el proyecto**:
```yaml
# ansible/inventories/gcp/group_vars/all.yml
gke_network_name: "todoapp-network"
gke_subnet_name: "todoapp-subnet"
gke_subnet_cidr: "10.0.0.0/24"
```

**Creación (Ansible)**:
```yaml
# ansible/tasks/setup-gke-cluster.yml
- name: Create VPC network
  command: >
    gcloud compute networks create {{ gke_network_name }}
    --subnet-mode=custom
    --bgp-routing-mode=regional
```

**Características**:
- **Aislamiento**: Tráfico separado de otras VPCs
- **Custom subnet**: Control total sobre rangos IP
- **Routing**: Regional (optimizado para us-central1)

**Propósito**:
- ✅ Seguridad: Aísla recursos del cluster
- ✅ Control: Gestión de IPs y subnets
- ✅ Conectividad: Base para servicios internos

### 2. Subnet

**Definición**: Segmento de red dentro de la VPC con rango IP específico.

**Configuración**:
```bash
gcloud compute networks subnets create todoapp-subnet \
  --network=todoapp-network \
  --range=10.0.0.0/24 \
  --region=us-central1
```

**Rango IP**: `10.0.0.0/24`
- Red: 10.0.0.0
- Máscara: /24 (255.255.255.0)
- IPs disponibles: 256 (10.0.0.0 - 10.0.0.255)
- IPs usables: 251 (GCP reserva 5)

**Asignación**:
- Nodos GKE: 10.0.0.2, 10.0.0.3, ...
- Pods: Rango secundario (alias IP)
- Services: Rango secundario separado

### 3. GKE (Google Kubernetes Engine)

**Definición**: Kubernetes administrado por Google.

**Ventajas vs. Kubernetes autoinstalado**:
- ✅ **Control plane gestionado**: Google mantiene master nodes
- ✅ **Autoscaling nativo**: Cluster Autoscaler integrado
- ✅ **Actualizaciones automáticas**: Seguridad y parches
- ✅ **Integración GCP**: Load Balancers, Persistent Disks, IAM

**Configuración del cluster**:
```yaml
gke_cluster_name: "todoapp-autoscaling-cluster"
gke_cluster_version: "latest"  # 1.33.5-gke.1162000
gke_node_pool:
  initial_node_count: 2
  min_node_count: 2
  max_node_count: 10
  machine_type: "e2-standard-2"  # 2 vCPU, 8 GB RAM
```

**Componentes clave**:
- **Control Plane** (managed por Google):
  - API Server
  - etcd
  - Controller Manager
  - Scheduler
- **Node Pool** (managed por nosotros):
  - Worker nodes (e2-standard-2)
  - Kubelet, kube-proxy
  - Container runtime (containerd)

### 4. GCR (Google Container Registry)

**Definición**: Registro privado de imágenes Docker en GCP.

**URL base**: `gcr.io/{project-id}/`

**Imágenes en este proyecto**:
```
gcr.io/todoapp-autoscaling-demo/todoapp-backend:latest
gcr.io/todoapp-autoscaling-demo/todoapp-frontend:latest
```

**Ventajas**:
- ✅ **Privado**: Solo accesible con credenciales GCP
- ✅ **Integrado**: GKE puede pull sin configuración extra
- ✅ **Versionado**: Soporte para tags y digests
- ✅ **Seguridad**: Escaneo de vulnerabilidades automático

**Autenticación**:
```bash
gcloud auth configure-docker
# Configura ~/.docker/config.json con credenciales
```

### 5. Persistent Disk

**Definición**: Almacenamiento persistente en GCP.

**Uso en el proyecto**: PostgreSQL data

**Configuración (Helm)**:
```yaml
# helm/todoapp/templates/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
spec:
  accessModes:
    - ReadWriteOnce          # Solo un pod puede escribir
  resources:
    requests:
      storage: 10Gi          # 10 GB
  storageClassName: standard # GCE Persistent Disk
```

**Características**:
- **Persistente**: Datos sobreviven a reinicios de pods
- **Respaldos automáticos**: GCP puede hacer snapshots
- **Performance**: standard (HDD) o ssd (SSD)

---

## Networking en Kubernetes

### Tipos de Services

| Tipo | Acceso | IP Externa | Uso en Proyecto |
|------|--------|------------|-----------------|
| **ClusterIP** | Solo interno | No | Backend, Postgres |
| **NodePort** | Interno + Node IP | No | No usado |
| **LoadBalancer** | Externo | Sí | Frontend |

### 1. ClusterIP (Backend y Postgres)

**Backend Service**:
```yaml
# helm/todoapp/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: todoapp-backend
spec:
  type: ClusterIP               # Solo accesible dentro del cluster
  selector:
    app: todoapp-backend
  ports:
    - port: 5000                # Puerto del service
      targetPort: 5000          # Puerto del container
```

**Características**:
- **IP interna**: Solo accesible desde dentro del cluster (10.x.x.x)
- **DNS**: Accesible como `todoapp-backend.todoapp.svc.cluster.local`
- **Shorthand**: Dentro del mismo namespace → `todoapp-backend`

**¿Por qué ClusterIP para backend?**
- ✅ **Seguridad**: No expuesto a Internet
- ✅ **Simplicidad**: Frontend hace proxy
- ✅ **Flexibilidad**: Pods pueden cambiar de IP, service es estable

**Postgres Service**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: todoapp-postgres
spec:
  type: ClusterIP
  selector:
    app: todoapp-postgres
  ports:
    - port: 5432
      targetPort: 5432
```

**Conexión desde Backend**:
```javascript
// backend/server.js
const pool = new Pool({
  host: process.env.POSTGRES_HOST || 'todoapp-postgres',  // DNS interno
  port: 5432,
  // ...
});
```

### 2. LoadBalancer (Frontend)

**Frontend Service**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: todoapp-frontend
spec:
  type: LoadBalancer           # Crea Load Balancer en GCP
  selector:
    app: todoapp-frontend
  ports:
    - port: 3000
      targetPort: 3000
```

**¿Qué hace GKE automáticamente?**
1. Crea **Google Cloud Load Balancer** (Layer 4)
2. Asigna **IP externa pública** (34.42.115.79)
3. Configura **health checks** al puerto 3000
4. Distribuye tráfico entre pods frontend

**Ver IP externa**:
```bash
kubectl get svc todoapp-frontend -n todoapp

# Salida:
# NAME               TYPE           EXTERNAL-IP      PORT(S)
# todoapp-frontend   LoadBalancer   34.42.115.79     3000:31234/TCP
```

---

## Load Balancer

### Tipo de Load Balancer

**Google Cloud Load Balancer**: Layer 4 (TCP/UDP)

**Características**:
- **Global anycast IP**: Enrutamiento optimizado
- **Health checks**: Verifica pods vivos
- **Session affinity**: Opcional (no usado)
- **Auto-scaling**: Se ajusta a número de pods

### Flujo de Tráfico en Load Balancer

```
Usuario → 34.42.115.79:3000
                │
                ▼
┌───────────────────────────────┐
│  Google Cloud Load Balancer   │
│  - Health check activo        │
│  - Round-robin balancing      │
└───────────────┬───────────────┘
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
  Frontend Pod 1   Frontend Pod 2
  10.x.1.5:3000    10.x.1.8:3000
```

**Algoritmo**: Round-robin (por defecto)
- Request 1 → Pod 1
- Request 2 → Pod 2
- Request 3 → Pod 1
- ...

**Health Checks**:
```yaml
# GCP automáticamente configura:
# - Path: /
# - Port: 3000
# - Interval: 8s
# - Timeout: 1s
# - Unhealthy threshold: 3 fallos consecutivos
```

Si un pod falla health check, LB deja de enviarle tráfico.

### Alternativas de Exposición

| Método | Ventaja | Desventaja |
|--------|---------|------------|
| **LoadBalancer** | Simple, IP pública | Costo (LB por service) |
| **Ingress** | 1 LB para N services | Más configuración |
| **NodePort** | Sin LB externo | Debe conocer IPs de nodos |

**Por qué usamos LoadBalancer**:
- ✅ Simplicidad para demo
- ✅ Un solo servicio expuesto
- ❌ En producción multi-service → usar Ingress

---

## Nginx como Reverse Proxy

### Problema Original

**Arquitectura inicial (no funcionaba en GCP)**:
```
Frontend (React) → API_URL: http://localhost:30001
                                     ↑
                          Funciona en Minikube (NodePort)
                          NO funciona en GCP LoadBalancer
```

**Razón del fallo**:
- `localhost` en el navegador del usuario apunta a su máquina
- Backend está en GCP, no en localhost

### Solución: Nginx Reverse Proxy

**Nueva arquitectura**:
```
Usuario → http://34.42.115.79:3000
                    ↓
            Frontend Pod (Nginx)
                    │
                    ├─ / → React App (archivos estáticos)
                    │
                    └─ /api/ → Proxy a todoapp-backend:5000/
                                        ↓
                               Backend Pod (Node.js)
```

### Configuración Nginx

**Archivo**: `frontend/nginx.conf`

```nginx
server {
    listen 3000;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Servir archivos estáticos de React
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Reverse Proxy para API
    location /api/ {
        proxy_pass http://todoapp-backend:5000/;  # ← DNS interno de K8s
        proxy_http_version 1.1;
        
        # Headers importantes
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

**Explicación línea por línea**:

```nginx
location /api/ {
```
- Match todas las URLs que empiecen con `/api/`
- Ejemplo: `/api/tasks` → match ✅

```nginx
    proxy_pass http://todoapp-backend:5000/;
```
- Reenvía request a `todoapp-backend` (Service interno)
- Puerto 5000
- **Trailing slash importante**: `/api/tasks` → `/tasks` (quita `/api`)

```nginx
    proxy_set_header Host $host;
```
- Mantiene el header `Host` original (`34.42.115.79`)
- Backend puede saber desde dónde vino el request

```nginx
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```
- Preserva IP real del cliente
- Útil para logs y analytics

```nginx
    proxy_set_header X-Forwarded-Proto $scheme;
```
- Indica protocolo original (http/https)
- Si luego se añade HTTPS, backend sabrá protocolo original

### Cambio en Frontend React

**Archivo**: `frontend/src/App.js`

**Antes**:
```javascript
const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:30001';
```

**Después**:
```javascript
const API_URL = process.env.REACT_APP_API_URL || '/api';
```

**¿Por qué `/api` sin dominio?**
- **Relative URL**: Navegador automáticamente usa mismo host
- Usuario en `http://34.42.115.79:3000`
- Request a `/api/tasks` → `http://34.42.115.79:3000/api/tasks`
- Nginx intercepta `/api/*` y proxy a backend

### Flujo de Request Completo

```
1. Usuario hace click "Cargar tareas"
                ↓
2. React ejecuta: fetch('/api/tasks')
                ↓
3. Navegador: GET http://34.42.115.79:3000/api/tasks
                ↓
4. Google Load Balancer → Frontend Pod
                ↓
5. Nginx recibe GET /api/tasks
                ↓
6. Nginx match location /api/
                ↓
7. Proxy a: http://todoapp-backend:5000/tasks
                ↓
8. Kubernetes DNS resuelve "todoapp-backend" → ClusterIP 10.x.y.z
                ↓
9. Backend Service → Backend Pod
                ↓
10. Node.js procesa GET /tasks
                ↓
11. PostgreSQL query: SELECT * FROM tasks
                ↓
12. Response JSON atraviesa camino inverso
                ↓
13. Usuario ve tareas en pantalla
```

### Ventajas de Reverse Proxy

| Ventaja | Descripción |
|---------|-------------|
| **Simplicidad Frontend** | No necesita conocer URL de backend |
| **CORS evitado** | Same-origin (mismo dominio) |
| **Seguridad** | Backend no expuesto directamente |
| **Flexibilidad** | Cambiar backend sin tocar frontend |
| **SSL Termination** | Nginx maneja HTTPS (si se configura) |
| **Caching** | Nginx puede cachear responses |

---

## Flujo de Tráfico Completo

### Request: Cargar Tareas

```
┌────────────────────────────────────────────────────────────┐
│ CAPA 1: CLIENTE                                            │
└────────────────────────────────────────────────────────────┘
Usuario → Navegador → GET http://34.42.115.79:3000/api/tasks
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 2: INTERNET                                            │
└────────────────────────────────────────────────────────────┘
DNS: 34.42.115.79 → Google Cloud Load Balancer
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 3: GCP LOAD BALANCER (Layer 4)                        │
└────────────────────────────────────────────────────────────┘
Health check → Frontend Pods vivos
Round-robin → Elige Frontend Pod 1
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 4: KUBERNETES SERVICE (todoapp-frontend)               │
└────────────────────────────────────────────────────────────┘
ClusterIP 10.x.1.100:3000
Iptables NAT → PodIP 10.x.1.5:3000
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 5: FRONTEND POD (Nginx)                               │
└────────────────────────────────────────────────────────────┘
Nginx recibe: GET /api/tasks HTTP/1.1
Match location /api/
Proxy a: http://todoapp-backend:5000/tasks
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 6: KUBERNETES DNS                                      │
└────────────────────────────────────────────────────────────┘
Resolve "todoapp-backend" → ClusterIP 10.x.2.50
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 7: KUBERNETES SERVICE (todoapp-backend)                │
└────────────────────────────────────────────────────────────┘
ClusterIP 10.x.2.50:5000
Selector: app=todoapp-backend
Round-robin → Backend Pod 2
Iptables NAT → PodIP 10.x.2.18:5000
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 8: BACKEND POD (Node.js)                              │
└────────────────────────────────────────────────────────────┘
Express recibe: GET /tasks
Route handler ejecuta
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 9: KUBERNETES SERVICE (todoapp-postgres)               │
└────────────────────────────────────────────────────────────┘
ClusterIP 10.x.3.100:5432
Selector: app=todoapp-postgres
→ Postgres Pod PodIP 10.x.3.25:5432
                                    │
┌───────────────────────────────────▼─────────────────────────┐
│ CAPA 10: POSTGRES POD                                       │
└────────────────────────────────────────────────────────────┘
PostgreSQL procesa: SELECT * FROM tasks
Lee de PersistentVolume (GCE Persistent Disk)
Response: [{"id": 1, "task": "..."}]
                                    │
                    ┌───────────────┘
                    │ Response path (inverso)
                    ▼
Usuario ve tareas en UI React
```

---

## Seguridad y Aislamiento

### Network Policies (Opcional, no implementado)

**Propósito**: Firewall a nivel de pod

**Ejemplo de política restrictiva**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      app: todoapp-backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: todoapp-frontend   # Solo frontend puede acceder
    ports:
    - protocol: TCP
      port: 5000
```

### Seguridad Actual

| Componente | Exposición | Acceso |
|------------|-----------|--------|
| **Frontend** | Público | Internet → LB → Pods |
| **Backend** | Privado | Solo desde Frontend (proxy) |
| **Postgres** | Privado | Solo desde Backend |

**Mejoras de seguridad futuras**:
- ✅ Implementar Network Policies
- ✅ Habilitar HTTPS en LoadBalancer
- ✅ Secrets encryption at rest
- ✅ Pod Security Standards
- ✅ Workload Identity (GCP)

---

## Conclusión

### Componentes Clave

| Componente | Responsabilidad | Capa |
|------------|----------------|------|
| **VPC Network** | Aislamiento de red | Infraestructura |
| **GKE Cluster** | Orquestación de containers | Plataforma |
| **Load Balancer** | Distribuir tráfico externo | Red (L4) |
| **Services (ClusterIP)** | Descubrimiento interno | Red (L4) |
| **Nginx** | Reverse proxy | Aplicación (L7) |
| **GCR** | Almacenamiento de imágenes | Registro |
| **Persistent Disk** | Almacenamiento persistente | Storage |

### Decisiones Arquitectónicas

1. **LoadBalancer para frontend**: Exposición simple y directa
2. **ClusterIP para backend/DB**: Seguridad por diseño
3. **Nginx como proxy**: Evita CORS, centraliza routing
4. **GCR para imágenes**: Integración nativa con GKE
5. **VPC custom**: Control total sobre networking

Esta arquitectura proporciona un balance entre simplicidad (para demo) y mejores prácticas de seguridad y escalabilidad.
