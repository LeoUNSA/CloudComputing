# Mecanismos de Autoscaling en Kubernetes y GCP

## Índice
1. [Introducción al Autoscaling](#introducción-al-autoscaling)
2. [HPA - Horizontal Pod Autoscaler](#hpa---horizontal-pod-autoscaler)
3. [Cluster Autoscaler](#cluster-autoscaler)
4. [Integración y Coordinación](#integración-y-coordinación)
5. [Configuración en este Proyecto](#configuración-en-este-proyecto)
6. [Políticas de Escalado](#políticas-de-escalado)
7. [Monitoreo y Validación](#monitoreo-y-validación)

---

## Introducción al Autoscaling

El autoscaling en Kubernetes tiene **dos niveles complementarios**:

| Nivel | Componente | Escala | Responsabilidad |
|-------|-----------|---------|-----------------|
| **Pod** | HPA (Horizontal Pod Autoscaler) | Pods | Ajusta réplicas de un Deployment |
| **Nodo** | Cluster Autoscaler | Nodos | Añade/elimina nodos del cluster |

### ¿Por Qué Autoscaling?

**Beneficios**:
- 💰 **Costos**: Paga solo por recursos usados
- 📈 **Performance**: Escala automáticamente ante demanda
- 🛡️ **Resiliencia**: Distribuye carga en múltiples pods/nodos
- 🌙 **Eficiencia**: Reduce recursos en horarios de baja demanda

**Escenario de Ejemplo**:
```
09:00 - Baja demanda → 2 pods, 2 nodos
12:00 - Pico de tráfico → 10 pods, 4 nodos (auto-scaled)
18:00 - Demanda normal → 3 pods, 2 nodos (scale-down)
```

---

## HPA - Horizontal Pod Autoscaler

### ¿Qué es HPA?

HPA es un controlador de Kubernetes que **ajusta automáticamente el número de réplicas de pods** en un Deployment, ReplicaSet o StatefulSet basándose en métricas observadas.

### Arquitectura HPA

```
┌─────────────────────────────────────────────────────────────┐
│  1. Métricas recolectadas cada 15 segundos                  │
│     metrics-server → CPU/Memory de pods                     │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  2. HPA Controller calcula réplicas deseadas                │
│     Formula: desiredReplicas = ceil[currentReplicas *       │
│              (currentMetric / targetMetric)]                │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Aplicar scale-up/down con políticas                     │
│     - Respetar stabilizationWindowSeconds                   │
│     - Aplicar limitadores de velocidad                      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Deployment actualiza número de réplicas                 │
│     - Crear nuevos pods (scale-up)                          │
│     - Terminar pods excedentes (scale-down)                 │
└─────────────────────────────────────────────────────────────┘
```

### Configuración HPA en este Proyecto

**Ubicación**: `helm/todoapp/templates/hpa.yaml`

#### HPA para Backend

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: todoapp-backend-hpa
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: todoapp-backend
  
  minReplicas: {{ .Values.autoscaling.backend.minReplicas }}      # 2
  maxReplicas: {{ .Values.autoscaling.backend.maxReplicas }}      # 10
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.backend.targetCPUUtilizationPercentage }}  # 50%
  
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.backend.targetMemoryUtilizationPercentage }}  # 70%
  
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Espera 5 minutos antes de scale-down
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60              # Máx 50% reducción por minuto
      - type: Pods
        value: 2
        periodSeconds: 60              # Máx 2 pods eliminados por minuto
      selectPolicy: Min                # Usa la política más conservadora
    
    scaleUp:
      stabilizationWindowSeconds: 0    # Scale-up inmediato
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15              # Puede duplicar pods en 15s
      - type: Pods
        value: 4
        periodSeconds: 15              # Máx 4 pods nuevos cada 15s
      selectPolicy: Max                # Usa la política más agresiva
```

#### HPA para Frontend

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: todoapp-frontend-hpa
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: todoapp-frontend
  
  minReplicas: {{ .Values.autoscaling.frontend.minReplicas }}     # 2
  maxReplicas: {{ .Values.autoscaling.frontend.maxReplicas }}     # 8
  
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.frontend.targetCPUUtilizationPercentage }}  # 60%
  
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.frontend.targetMemoryUtilizationPercentage }}  # 75%
  
  behavior:
    # Mismo comportamiento que backend
    scaleDown:
      stabilizationWindowSeconds: 300
      # ...
```

### Variables de Configuración HPA

**Ubicación**: `ansible/inventories/gcp/group_vars/all.yml`

```yaml
autoscaling:
  backend:
    min_replicas: 2                    # Mínimo siempre activo
    max_replicas: 10                   # Límite superior
    target_cpu_utilization: 50         # Scale-up si CPU > 50%
    target_memory_utilization: 70      # Scale-up si Memory > 70%
  
  frontend:
    min_replicas: 2
    max_replicas: 8
    target_cpu_utilization: 60         # Frontend tolera más CPU
    target_memory_utilization: 75
```

### Fórmula de Cálculo de Réplicas

```
desiredReplicas = ceil[currentReplicas × (currentMetric / targetMetric)]
```

**Ejemplo real** (Backend con CPU):
```
Situación inicial:
- currentReplicas = 2
- targetCPU = 50%
- currentCPU = 85% (promedio de todos los pods)

Cálculo:
desiredReplicas = ceil[2 × (85 / 50)]
                = ceil[2 × 1.7]
                = ceil[3.4]
                = 4 pods

Resultado: HPA escala de 2 → 4 pods
```

### Tipos de Métricas Soportadas

| Tipo | Descripción | Ejemplo |
|------|-------------|---------|
| **Resource** | CPU, Memory del pod | `cpu.averageUtilization: 50%` |
| **Pods** | Métricas custom por pod | `http_requests_per_second: 100` |
| **Object** | Métricas de objetos K8s | `ingress.requests_per_second` |
| **External** | Métricas externas | `sqs_queue_length` (AWS SQS) |

**En este proyecto** solo usamos **Resource** (CPU y Memory).

---

## Cluster Autoscaler

### ¿Qué es Cluster Autoscaler?

Cluster Autoscaler es un componente que **añade o elimina nodos** en el cluster basándose en:

1. **Pods pendientes**: Pods que no pueden programarse por falta de recursos
2. **Nodos infrautilizados**: Nodos con baja utilización durante periodo prolongado

### Arquitectura Cluster Autoscaler

```
┌─────────────────────────────────────────────────────────────┐
│  Escenario 1: SCALE-UP (añadir nodos)                       │
└─────────────────────────────────────────────────────────────┘

1. HPA crea nuevos pods (demanda alta)
                   ↓
2. Scheduler intenta asignar pods a nodos
                   ↓
3. No hay recursos → Pods quedan en estado "Pending"
                   ↓
4. Cluster Autoscaler detecta pods Pending (cada 10s)
                   ↓
5. Calcula número de nodos necesarios
                   ↓
6. Solicita nuevos nodos al proveedor cloud (GCP)
                   ↓
7. Nodos se aprovisionan (2-3 minutos)
                   ↓
8. Scheduler asigna pods pendientes a nuevos nodos
                   ↓
9. Pods pasan de Pending → Running

┌─────────────────────────────────────────────────────────────┐
│  Escenario 2: SCALE-DOWN (eliminar nodos)                   │
└─────────────────────────────────────────────────────────────┘

1. HPA reduce número de pods (demanda baja)
                   ↓
2. Algunos nodos quedan con poca carga (<50% recursos)
                   ↓
3. Cluster Autoscaler espera 10 minutos (unneeded-time)
                   ↓
4. Si carga sigue baja, marca nodo como "unneeded"
                   ↓
5. Drena pods del nodo (los mueve a otros nodos)
                   ↓
6. Elimina nodo del cluster
                   ↓
7. GCP libera la VM (ahorro de costos)
```

### Configuración en GKE

**Ubicación**: `ansible/tasks/setup-gke-cluster.yml`

```yaml
- name: Create GKE cluster with autoscaling
  command: >
    gcloud container clusters create {{ gke_cluster_name }}
    --zone={{ gcp_zone }}
    --num-nodes={{ gke_node_pool.initial_node_count }}     # 2 nodos iniciales
    --min-nodes={{ gke_node_pool.min_node_count }}         # Mínimo: 2
    --max-nodes={{ gke_node_pool.max_node_count }}         # Máximo: 10
    --enable-autoscaling                                   # ← ACTIVA CLUSTER AUTOSCALER
    --machine-type={{ gke_node_pool.machine_type }}        # e2-standard-2
    --enable-autorepair
    --enable-autoupgrade
```

### Variables de Node Pool

**Ubicación**: `ansible/inventories/gcp/group_vars/all.yml`

```yaml
gke_node_pool:
  initial_node_count: 2    # Nodos al crear cluster
  min_node_count: 2        # Nunca menos de 2 nodos
  max_node_count: 10       # Límite superior (escala hasta 10)
  machine_type: "e2-standard-2"
  disk_size_gb: 50
```

### Parámetros Clave del Cluster Autoscaler

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| `scan-interval` | 10s | Frecuencia de evaluación |
| `scale-down-unneeded-time` | 10m | Tiempo antes de eliminar nodo |
| `scale-down-delay-after-add` | 10m | Espera tras añadir nodo |
| `scale-down-utilization-threshold` | 0.5 | Umbral de utilización (50%) |
| `max-node-provision-time` | 15m | Timeout para provisionar nodo |

### Condiciones para Scale-Down

Un nodo se elimina **solo si**:
1. ✅ Utilización < 50% por más de 10 minutos
2. ✅ Todos sus pods pueden moverse a otros nodos
3. ✅ No tiene pods con `PodDisruptionBudget` que impida el drain
4. ✅ No tiene pods con `local-storage` crítico
5. ✅ Cluster tiene > min_node_count nodos

---

## Integración y Coordinación

### Interacción HPA ↔ Cluster Autoscaler

```
┌─────────────────────────────────────────────────────────────┐
│  FASE 1: Demanda aumenta gradualmente                       │
└─────────────────────────────────────────────────────────────┘

T=0:    2 pods backend, 2 nodos (recursos suficientes)
        CPU: 30% → HPA no actúa

T=2min: CPU: 65% (> 50% target)
        ↓
        HPA escala: 2 → 4 pods
        ↓
        4 pods asignados a 2 nodos (aún caben)
        CPU por nodo: 80%

┌─────────────────────────────────────────────────────────────┐
│  FASE 2: Demanda aumenta fuertemente                        │
└─────────────────────────────────────────────────────────────┘

T=5min: CPU: 85% (muy alto)
        ↓
        HPA escala: 4 → 8 pods
        ↓
        Scheduler intenta asignar 4 pods nuevos
        ↓
        Solo caben 2 pods más (CPU/Memory límite)
        ↓
        2 pods quedan en estado "Pending"
        ↓
        ┌──────────────────────────────────────┐
        │  CLUSTER AUTOSCALER ACTÚA            │
        └──────────────────────────────────────┘
        ↓
        Detecta 2 pods Pending (cada 10s)
        ↓
        Calcula: necesita 1 nodo adicional
        ↓
        Solicita nodo a GCP
        ↓
        Espera 2-3 min (aprovisionamiento)
        ↓
        Nodo 3 se une al cluster
        ↓
        Scheduler asigna los 2 pods Pending al nodo 3
        ↓
        8 pods Running distribuidos en 3 nodos

┌─────────────────────────────────────────────────────────────┐
│  FASE 3: Demanda disminuye                                  │
└─────────────────────────────────────────────────────────────┘

T=20min: Carga eliminada, CPU: 5%
         ↓
         HPA espera stabilizationWindow (5 min)
         ↓
T=25min: HPA escala: 8 → 3 pods
         ↓
         Nodo 3 queda con 0 pods asignados
         ↓
         Cluster Autoscaler espera 10 min
         ↓
T=35min: Si nodo sigue vacío, se elimina
         ↓
         Cluster vuelve a 2 nodos
```

### Caso Real del Proyecto

**Demostración ejecutada**:

```bash
# Estado inicial
$ kubectl get hpa -n todoapp
NAME                  REFERENCE                  TARGETS    MINPODS   MAXPODS   REPLICAS
todoapp-backend-hpa   Deployment/todoapp-backend 2%/50%     2         10        2

$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE
gke-...-default-pool-abc123                Ready    <none>   10m
gke-...-default-pool-def456                Ready    <none>   10m
# 2 nodos iniciales

# Generamos carga (10 generadores)
$ kubectl run load-gen-{1..10} --image=busybox ...

# Después de 3 minutos
$ kubectl get hpa -n todoapp
NAME                  REFERENCE                  TARGETS    MINPODS   MAXPODS   REPLICAS
todoapp-backend-hpa   Deployment/todoapp-backend 95%/50%    2         10        10
# ↑ HPA escaló a 10 pods (máximo)

$ kubectl get pods -n todoapp | grep backend
todoapp-backend-xxx   Running   node-1
todoapp-backend-yyy   Running   node-1
todoapp-backend-zzz   Running   node-2
...
todoapp-backend-www   Pending             # ← 1 pod sin recursos
# ↑ 9 pods running, 1 pending

# Después de 2 minutos (Cluster Autoscaler actúa)
$ kubectl get nodes
NAME                                       STATUS   ROLES    AGE
gke-...-default-pool-abc123                Ready    <none>   13m
gke-...-default-pool-def456                Ready    <none>   13m
gke-...-default-pool-ghi789                Ready    <none>   30s
# ↑ Nodo 3 añadido automáticamente

$ kubectl get pods -n todoapp -o wide
...
todoapp-backend-www   Running   node-3
# ↑ Pod pendiente ahora en nodo 3
```

---

## Políticas de Escalado

### Scale Behaviors (HPA v2)

#### Scale-Down (Reducción de Pods)

```yaml
scaleDown:
  stabilizationWindowSeconds: 300  # 5 minutos de ventana
  policies:
  - type: Percent    # Política 1: Porcentual
    value: 50
    periodSeconds: 60
    # Máximo 50% de reducción cada 60 segundos
  
  - type: Pods       # Política 2: Absoluta
    value: 2
    periodSeconds: 60
    # Máximo 2 pods eliminados cada 60 segundos
  
  selectPolicy: Min  # Usa la más conservadora
```

**Ejemplo**:
```
Situación: 10 pods → necesita reducir a 4 pods

Política Percent: 10 × 50% = 5 pods/min → 2 minutos total
Política Pods:    2 pods/min           → 3 minutos total

selectPolicy: Min → elige Pods policy (más lenta)

Timeline:
T=0:   10 pods
T=60s:  8 pods (-2)
T=120s: 6 pods (-2)
T=180s: 4 pods (-2)
```

#### Scale-Up (Aumento de Pods)

```yaml
scaleUp:
  stabilizationWindowSeconds: 0  # Sin espera (respuesta inmediata)
  policies:
  - type: Percent
    value: 100       # Puede duplicar pods
    periodSeconds: 15
  
  - type: Pods
    value: 4
    periodSeconds: 15
  
  selectPolicy: Max  # Usa la más agresiva
```

**Ejemplo**:
```
Situación: 2 pods → necesita 10 pods (carga alta)

Política Percent: 2 × 100% = 4 pods cada 15s
Política Pods:    4 pods cada 15s

selectPolicy: Max → ambas iguales en este caso

Timeline:
T=0:   2 pods
T=15s: 6 pods (+4)
T=30s: 10 pods (+4)
```

### Evitar Flapping (Oscilaciones)

**Problema**: Sin `stabilizationWindow`, HPA puede oscilar:
```
10:00 → 2 pods (CPU bajo)
10:05 → 6 pods (CPU alto por startup)
10:10 → 2 pods (CPU se normaliza)
10:15 → 6 pods (CPU alto de nuevo)
```

**Solución**: `stabilizationWindowSeconds: 300`
```
10:00 → 2 pods (CPU bajo)
10:05 → CPU sube (HPA considera últimos 5 min)
10:10 → CPU promedio sigue bajo → no escala
```

---

## Monitoreo y Validación

### Comandos de Monitoreo HPA

```bash
# Ver estado actual de HPA
kubectl get hpa -n todoapp

# Salida:
# NAME                  REFERENCE                  TARGETS         MINPODS   MAXPODS   REPLICAS
# todoapp-backend-hpa   Deployment/todoapp-backend 35%/50%, 45%/70%   2         10        3
#                                                  ↑CPU    ↑Memory

# Ver detalles y eventos de HPA
kubectl describe hpa todoapp-backend-hpa -n todoapp

# Ver métricas en tiempo real
kubectl top pods -n todoapp

# Monitoreo continuo (cada 2s)
watch kubectl get hpa -n todoapp
```

### Comandos de Monitoreo Cluster Autoscaler

```bash
# Ver nodos del cluster
kubectl get nodes

# Ver detalles de un nodo (capacidad, utilización)
kubectl describe node <node-name>

# Ver eventos del cluster (incluye CA events)
kubectl get events -n kube-system | grep cluster-autoscaler

# Ver pods por nodo
kubectl get pods -n todoapp -o wide

# Ver logs del Cluster Autoscaler
kubectl logs -f -n kube-system deployment/cluster-autoscaler
```

### Métricas Clave

| Métrica | Comando | Qué observar |
|---------|---------|--------------|
| **CPU por Pod** | `kubectl top pods -n todoapp` | > target → scale-up |
| **Réplicas actuales** | `kubectl get hpa -n todoapp` | REPLICAS columna |
| **Pods Pending** | `kubectl get pods -n todoapp` | Estado Pending |
| **Número de nodos** | `kubectl get nodes` | Incremento/decremento |
| **Utilización nodo** | `kubectl describe node <name>` | Allocated resources |

### Validar Configuración

```bash
# Verificar HPA está activo
kubectl get hpa -n todoapp

# Verificar metrics-server funciona
kubectl top nodes
kubectl top pods -n todoapp

# Verificar Cluster Autoscaler habilitado
gcloud container clusters describe todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --format="value(autoscaling)"

# Salida esperada:
# Autoscaling profile: BALANCED
# Enabled: True
# Min nodes: 2
# Max nodes: 10
```

---

## Conclusión

### Resumen de Componentes

| Componente | Qué escala | Trigger | Tiempo |
|------------|-----------|---------|--------|
| **HPA** | Pods | CPU/Memory > target | 15-60s |
| **Cluster Autoscaler** | Nodos | Pods Pending | 2-3 min |
| **metrics-server** | - | Provee métricas | 15s refresh |

### Mejores Prácticas

1. ✅ **Configurar requests/limits** en Deployments (HPA necesita estos valores)
2. ✅ **Usar stabilizationWindow** para evitar flapping
3. ✅ **Monitorear eventos** para troubleshooting
4. ✅ **Probar scale-down** (suele ser más problemático)
5. ✅ **Configurar PodDisruptionBudgets** para evitar downtime

### Limitaciones

- ❌ HPA no puede escalar a 0 pods (min: 1)
- ❌ Cluster Autoscaler tarda minutos (no segundos)
- ❌ Scale-down es conservador (10 min espera)
- ❌ Solo métricas Resource sin custom metrics en esta versión

Este sistema de autoscaling dual proporciona elasticidad completa desde pods hasta infraestructura, optimizando costos y performance automáticamente.
