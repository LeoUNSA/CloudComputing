# Generación de Tráfico para Pruebas de Autoscaling

## Índice
1. [Introducción](#introducción)
2. [Endpoint de Stress en el Backend](#endpoint-de-stress-en-el-backend)
3. [Métodos de Generación de Carga](#métodos-de-generación-de-carga)
4. [Scripts de Load Testing](#scripts-de-load-testing)
5. [Cómo Funciona la Generación de CPU](#cómo-funciona-la-generación-de-cpu)
6. [Patrones de Carga](#patrones-de-carga)
7. [Troubleshooting de Load Tests](#troubleshooting-de-load-tests)

---

## Introducción

Para demostrar el autoscaling, necesitamos generar **carga artificial** que haga que el CPU de los pods supere el umbral configurado en el HPA (50% para backend).

**Componentes clave**:
1. **Endpoint `/stress`** en el backend (genera CPU intensivo)
2. **Pods BusyBox** que llaman repetidamente al endpoint
3. **Scripts automatizados** para facilitar la generación de carga

---

## Endpoint de Stress en el Backend

### Ubicación del Código

**Archivo**: `backend/server.js`

### Implementación Completa

```javascript
// Endpoint para generar carga de CPU (stress testing)
app.get('/stress', (req, res) => {
  const duration = parseInt(req.query.duration) || 30000; // Default: 30 segundos
  const startTime = Date.now();
  
  console.log(`[STRESS] Iniciando generación de CPU por ${duration}ms`);
  
  // Loop intensivo de CPU
  let counter = 0;
  while (Date.now() - startTime < duration) {
    // Operaciones matemáticas intensivas
    counter++;
    Math.sqrt(counter);
    Math.sin(counter);
    Math.cos(counter);
    Math.pow(counter, 2);
    
    // Cada millón de iteraciones, verificar tiempo
    if (counter % 1000000 === 0) {
      const elapsed = Date.now() - startTime;
      console.log(`[STRESS] ${elapsed}ms transcurridos, counter: ${counter}`);
    }
  }
  
  const totalTime = Date.now() - startTime;
  console.log(`[STRESS] Completado. Tiempo total: ${totalTime}ms, Iteraciones: ${counter}`);
  
  res.json({
    message: 'Stress test completed',
    duration: totalTime,
    iterations: counter
  });
});
```

### Parámetros del Endpoint

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `duration` | Query param | 30000 | Duración en milisegundos |

### Ejemplos de Uso

```bash
# Stress de 10 segundos
curl http://todoapp-backend:5000/stress?duration=10000

# Stress de 40 segundos (más intenso)
curl http://todoapp-backend:5000/stress?duration=40000

# Stress de 1 minuto
curl http://todoapp-backend:5000/stress?duration=60000
```

### Response del Endpoint

```json
{
  "message": "Stress test completed",
  "duration": 40123,
  "iterations": 15678234
}
```

### ¿Por Qué Estas Operaciones?

```javascript
Math.sqrt(counter);  // Raíz cuadrada (floating point)
Math.sin(counter);   // Seno (trigonometría, FPU intensivo)
Math.cos(counter);   // Coseno (trigonometría, FPU intensivo)
Math.pow(counter, 2); // Potencia (operación aritmética)
```

**Objetivo**: Operaciones que consumen CPU sin hacer I/O
- ✅ **CPU-bound**: No usa disco, red o memoria intensivamente
- ✅ **Predecible**: Duración controlada por parámetro
- ✅ **Medible**: Logs muestran progreso

### Logs del Backend Durante Stress

```
[STRESS] Iniciando generación de CPU por 40000ms
[STRESS] 1234ms transcurridos, counter: 1000000
[STRESS] 2456ms transcurridos, counter: 2000000
[STRESS] 3678ms transcurridos, counter: 3000000
...
[STRESS] 39876ms transcurridos, counter: 14000000
[STRESS] Completado. Tiempo total: 40012ms, Iteraciones: 14567890
```

---

## Métodos de Generación de Carga

### Método 1: Pod BusyBox Manual (Simple)

**Ventaja**: Un solo comando, fácil de entender

```bash
# Crear pod que llama al endpoint en loop
kubectl run load-gen-1 --image=busybox --restart=Never -n todoapp -- \
  /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
```

**¿Qué hace cada parte?**

```bash
kubectl run load-gen-1        # Nombre del pod
--image=busybox               # Imagen mínima de Linux con wget
--restart=Never               # Pod único (no Deployment)
-n todoapp                    # Namespace
-- /bin/sh -c "..."           # Comando a ejecutar en el container
```

**Comando dentro del container**:
```bash
while true; do
  wget -q -O- http://todoapp-backend:5000/stress?duration=40000
done
```

- `while true`: Loop infinito
- `wget -q -O-`: Hacer HTTP GET, output a stdout, modo silencioso
- `http://todoapp-backend:5000/stress?duration=40000`: URL del endpoint
- Cada 40 segundos completa un ciclo, inmediatamente inicia otro

### Método 2: Múltiples Pods BusyBox (Alta Carga)

**Ventaja**: Genera más carga, provoca escalado más rápido

```bash
# Crear 5 generadores simultáneos
for i in {1..5}; do
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
done
```

**Resultado**: 5 pods llamando al endpoint simultáneamente

```
load-gen-1 → backend-pod-1 (CPU 100%)
load-gen-2 → backend-pod-2 (CPU 100%)
load-gen-3 → backend-pod-1 (CPU 100%)
load-gen-4 → backend-pod-2 (CPU 100%)
load-gen-5 → backend-pod-1 (CPU 100%)

→ HPA detecta CPU alto → escala
```

### Método 3: Deployment de Load Generators (Extremo)

**Ventaja**: Escalable, puede generar carga masiva

```yaml
# load-gen-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: todoapp
spec:
  replicas: 10  # 10 generadores simultáneos
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
    spec:
      containers:
      - name: load-gen
        image: busybox
        command:
        - /bin/sh
        - -c
        - |
          while true; do
            wget -q -O- http://todoapp-backend:5000/stress?duration=40000
            sleep 1
          done
```

```bash
# Aplicar
kubectl apply -f load-gen-deployment.yaml

# Escalar a 20 generadores
kubectl scale deployment load-generator --replicas=20 -n todoapp
```

---

## Scripts de Load Testing

El proyecto incluye scripts automatizados en `load-testing/`.

### Script 1: `simple-load-test.sh`

**Propósito**: Generar carga básica con un solo comando

```bash
#!/bin/bash

# Configuración
NAMESPACE="todoapp"
NUM_GENERATORS=5
DURATION=40000  # 40 segundos

echo "🚀 Iniciando generadores de carga..."

# Crear pods de carga
for i in $(seq 1 $NUM_GENERATORS); do
  kubectl run load-gen-$i \
    --image=busybox \
    --restart=Never \
    -n $NAMESPACE \
    -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=$DURATION; done" \
    2>/dev/null
  
  echo "  ✓ Generador $i creado"
done

echo ""
echo "✅ $NUM_GENERATORS generadores activos"
echo "📊 Monitorea con: kubectl get hpa -n $NAMESPACE"
echo "🛑 Para detener: kubectl delete pod -l run=load-gen-1 -n $NAMESPACE"
```

**Uso**:
```bash
cd load-testing
chmod +x simple-load-test.sh
./simple-load-test.sh
```

### Script 2: `monitor-autoscaling.sh`

**Propósito**: Monitoreo visual del autoscaling

```bash
#!/bin/bash

NAMESPACE="todoapp"

echo "📊 Monitoreando Autoscaling en tiempo real..."
echo "Presiona Ctrl+C para salir"
echo ""

while true; do
  clear
  
  # Timestamp
  echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # HPA Status
  echo "📈 HORIZONTAL POD AUTOSCALER (HPA)"
  kubectl get hpa -n $NAMESPACE 2>/dev/null || echo "  ⚠️  HPA no disponible"
  echo ""
  
  # Nodos
  echo "🖥️  NODOS DEL CLUSTER"
  kubectl get nodes 2>/dev/null || echo "  ⚠️  No se pueden obtener nodos"
  echo ""
  
  # Pods Backend
  echo "🔷 PODS BACKEND"
  kubectl get pods -n $NAMESPACE -l app=todoapp-backend -o wide 2>/dev/null | head -15
  echo ""
  
  # CPU de pods
  echo "⚡ USO DE CPU POR POD"
  kubectl top pods -n $NAMESPACE -l app=todoapp-backend 2>/dev/null || echo "  ⚠️  Métricas no disponibles"
  echo ""
  
  # Load generators
  LOAD_GENS=$(kubectl get pods -n $NAMESPACE 2>/dev/null | grep -c "load-gen-" || echo "0")
  echo "🔥 Generadores de carga activos: $LOAD_GENS"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  sleep 5
done
```

**Uso**:
```bash
./load-testing/monitor-autoscaling.sh
```

**Output ejemplo**:
```
🕐 2025-10-30 15:23:45
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📈 HORIZONTAL POD AUTOSCALER (HPA)
NAME                  REFERENCE                  TARGETS      MINPODS   MAXPODS   REPLICAS
todoapp-backend-hpa   Deployment/todoapp-backend 85%/50%      2         10        6

🖥️  NODOS DEL CLUSTER
NAME                                       STATUS   ROLES    AGE   VERSION
gke-...-default-pool-abc123                Ready    <none>   20m   v1.33.5
gke-...-default-pool-def456                Ready    <none>   20m   v1.33.5
gke-...-default-pool-ghi789                Ready    <none>   3m    v1.33.5

🔷 PODS BACKEND
NAME                               READY   STATUS    NODE
todoapp-backend-7fdd46d596-2c4s4   1/1     Running   gke-...-abc123
todoapp-backend-7fdd46d596-5k8w9   1/1     Running   gke-...-def456
todoapp-backend-7fdd46d596-7p2m1   1/1     Running   gke-...-abc123
todoapp-backend-7fdd46d596-9x5t3   1/1     Running   gke-...-def456
todoapp-backend-7fdd46d596-h4n6k   1/1     Running   gke-...-ghi789
todoapp-backend-7fdd46d596-m8r2w   1/1     Running   gke-...-ghi789

⚡ USO DE CPU POR POD
NAME                               CPU(cores)   MEMORY(bytes)
todoapp-backend-7fdd46d596-2c4s4   876m         45Mi
todoapp-backend-7fdd46d596-5k8w9   892m         47Mi
...

🔥 Generadores de carga activos: 5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Script 3: `extreme-load-test.sh`

**Propósito**: Forzar escalado de nodos (Cluster Autoscaler)

```bash
#!/bin/bash

NAMESPACE="todoapp"
NUM_GENERATORS=15  # Número alto para forzar nodos nuevos
DURATION=60000     # 60 segundos

echo "⚠️  EXTREME LOAD TEST - Forzará escalado de nodos"
echo ""
read -p "¿Continuar? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cancelado"
  exit 0
fi

echo ""
echo "🔥 Creando $NUM_GENERATORS generadores de carga..."

for i in $(seq 1 $NUM_GENERATORS); do
  kubectl run extreme-load-gen-$i \
    --image=busybox \
    --restart=Never \
    -n $NAMESPACE \
    --requests=cpu=200m \
    --requests=memory=64Mi \
    -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=$DURATION; sleep 2; done" \
    2>/dev/null
  
  echo "  ✓ Generador extremo $i creado (requests: 200m CPU, 64Mi RAM)"
done

echo ""
echo "✅ $NUM_GENERATORS generadores extremos activos"
echo ""
echo "🎯 Esto debería:"
echo "   1. Escalar backend a 10 pods (máximo)"
echo "   2. Provocar pods en estado 'Pending'"
echo "   3. Activar Cluster Autoscaler"
echo "   4. Añadir nuevos nodos al cluster"
echo ""
echo "📊 Monitorea con: watch kubectl get nodes"
echo "🛑 Para detener: kubectl delete pod -n $NAMESPACE -l run=extreme-load-gen-1"
```

**Diferencia clave**: Añade **resource requests**
```bash
--requests=cpu=200m      # Cada generador pide 200 milicores
--requests=memory=64Mi   # Y 64 MB de RAM
```

Esto fuerza al scheduler a considerar recursos, provocando `Pending` más rápido.

### Script 4: `run-load-test.sh`

**Propósito**: Script completo con generación + monitoreo

```bash
#!/bin/bash

NAMESPACE="todoapp"

echo "═══════════════════════════════════════════════════════════════"
echo "  🚀 AUTOSCALING LOAD TEST - TodoApp GKE Demo"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Verificar estado inicial
echo "📋 Estado inicial del cluster:"
echo ""
kubectl get nodes
echo ""
kubectl get hpa -n $NAMESPACE
echo ""

# Confirmar
read -p "¿Iniciar test de carga? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Cancelado"
  exit 0
fi

# Crear generadores
echo ""
echo "🔥 Creando generadores de carga..."
for i in {1..8}; do
  kubectl run load-gen-$i \
    --image=busybox \
    --restart=Never \
    -n $NAMESPACE \
    -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done" \
    2>/dev/null && echo "  ✓ load-gen-$i"
done

echo ""
echo "✅ Generadores activos"
echo ""
echo "⏳ Esperando 30 segundos antes de iniciar monitoreo..."
sleep 30

# Monitoreo
echo ""
echo "📊 Iniciando monitoreo (Ctrl+C para salir)..."
echo ""
sleep 2

# Loop de monitoreo
while true; do
  clear
  echo "═══════════════════════════════════════════════════════════════"
  echo "  📊 AUTOSCALING MONITORING - $(date '+%H:%M:%S')"
  echo "═══════════════════════════════════════════════════════════════"
  echo ""
  
  echo "📈 HPA STATUS:"
  kubectl get hpa -n $NAMESPACE
  echo ""
  
  echo "🖥️  NODES:"
  kubectl get nodes
  echo ""
  
  echo "🔷 BACKEND PODS:"
  kubectl get pods -n $NAMESPACE -l app=todoapp-backend
  echo ""
  
  echo "⚡ CPU USAGE:"
  kubectl top pods -n $NAMESPACE -l app=todoapp-backend 2>/dev/null || echo "Métricas no disponibles"
  echo ""
  
  echo "═══════════════════════════════════════════════════════════════"
  echo "Próxima actualización en 5s... (Ctrl+C para salir)"
  
  sleep 5
done
```

---

## Cómo Funciona la Generación de CPU

### Flujo Completo

```
┌─────────────────────────────────────────────────────────────────┐
│  1. kubectl run crea pod BusyBox                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Container ejecuta: while true; do wget ...; done            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. wget hace HTTP GET a http://todoapp-backend:5000/stress     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Kubernetes DNS resuelve "todoapp-backend" → ClusterIP       │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Service round-robin → elige un Backend Pod                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  6. Backend Pod ejecuta endpoint /stress                        │
│     - Loop de 40 segundos                                       │
│     - Operaciones Math.* intensivas                             │
│     - CPU del pod → 100%                                        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  7. metrics-server muestrea CPU cada 15s                        │
│     - Detecta: CPU = 95% (> 50% target)                         │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  8. HPA Controller calcula:                                     │
│     desiredReplicas = ceil[2 × (95 / 50)] = 4                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  9. Deployment escala: 2 → 4 pods                               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  10. Load generators siguen llamando → CPU sigue alto           │
│      Proceso se repite hasta max_replicas (10)                  │
└─────────────────────────────────────────────────────────────────┘
```

### Timeline Real de CPU

```
T=0s:     2 pods, CPU promedio: 2%
          ↓
          Iniciar 5 generadores
          ↓
T=5s:     wget llega a pods → empieza stress
          Pod 1 CPU: 100%
          Pod 2 CPU: 100%
          Promedio: 100% (pero HPA muestrea cada 15s)
          ↓
T=15s:    metrics-server lee: CPU = 95%
          ↓
T=20s:    HPA calcula: 2 × (95/50) = 3.8 → 4 pods
          ↓
T=25s:    4 pods running
          Load generators distribuidos:
          - load-gen-1 → pod-1 (CPU 100%)
          - load-gen-2 → pod-2 (CPU 100%)
          - load-gen-3 → pod-3 (CPU 100%)
          - load-gen-4 → pod-4 (CPU 100%)
          - load-gen-5 → pod-1 (CPU 100%)
          ↓
T=30s:    metrics-server lee: CPU = 90%
          ↓
T=35s:    HPA calcula: 4 × (90/50) = 7.2 → 8 pods
          ↓
          ... proceso continúa hasta 10 pods
```

---

## Patrones de Carga

### Patrón 1: Carga Sostenida (Recomendado para Demo)

```bash
# 5 generadores con duración larga
for i in {1..5}; do
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
done
```

**Características**:
- ✅ Predecible: Carga constante
- ✅ Observable: Tiempo suficiente para ver escalado
- ✅ Reversible: Fácil de detener

**Resultado esperado**: HPA escala a 8-10 pods en 3-4 minutos

### Patrón 2: Carga Extrema (Forzar Cluster Autoscaler)

```bash
# 15 generadores con resource requests
for i in {1..15}; do
  kubectl run extreme-load-$i --image=busybox --restart=Never -n todoapp \
    --requests=cpu=200m --requests=memory=64Mi -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=60000; sleep 1; done"
done
```

**Características**:
- 🔥 Alta demanda: 15 generadores + resource requests
- 🔥 Fuerza Pending: Scheduler no puede asignar todos los pods
- 🔥 Activa CA: Cluster Autoscaler añade nodos

**Resultado esperado**: 
- HPA escala a 10 pods (máximo)
- 1-2 pods quedan Pending
- Cluster Autoscaler añade nodo en 2-3 minutos

### Patrón 3: Carga Gradual (Educativo)

```bash
# Fase 1: Carga ligera (1 generador)
kubectl run load-gen-1 --image=busybox --restart=Never -n todoapp -- \
  /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=30000; done"

# Esperar 2 minutos, observar
sleep 120

# Fase 2: Incrementar (3 generadores más)
for i in {2..4}; do
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=30000; done"
done

# Esperar 2 minutos, observar
sleep 120

# Fase 3: Máxima carga (10 generadores)
for i in {5..10}; do
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=30000; done"
done
```

**Características**:
- 📚 Educativo: Muestra escalado gradual
- 📊 Observable: Fases claras de escalado
- ⏱️ Largo: Requiere ~10 minutos

---

## Troubleshooting de Load Tests

### Problema 1: Generadores No Causan Escalado

**Síntoma**:
```bash
kubectl get hpa -n todoapp
# TARGETS: 2%/50%  (CPU muy bajo)
```

**Diagnóstico**:

```bash
# Verificar que generadores están corriendo
kubectl get pods -n todoapp | grep load-gen

# Verificar logs de un generador
kubectl logs load-gen-1 -n todoapp

# Verificar que endpoint /stress funciona
kubectl exec -it load-gen-1 -n todoapp -- wget -O- http://todoapp-backend:5000/stress?duration=10000
```

**Posibles causas**:
1. Generadores no se crearon correctamente
2. Service backend no resuelve
3. Endpoint /stress tiene error

**Solución**:
```bash
# Recrear generadores
kubectl delete pod -n todoapp -l run=load-gen-1
for i in {1..5}; do kubectl run load-gen-$i ...; done
```

### Problema 2: CPU Sube Pero HPA No Escala

**Síntoma**:
```bash
kubectl top pods -n todoapp
# NAME                CPU(cores)
# todoapp-backend-xxx 950m        ← Alto CPU

kubectl get hpa -n todoapp
# TARGETS: <unknown>/50%          ← Métricas no disponibles
```

**Diagnóstico**:

```bash
# Verificar metrics-server
kubectl get deployment metrics-server -n kube-system

# Verificar API de métricas
kubectl top nodes
```

**Solución**:
```bash
# Reinstalar metrics-server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}

# Esperar 30 segundos y verificar
kubectl top pods -n todoapp
```

### Problema 3: HPA Escala Pero Pods Quedan Pending

**Síntoma**:
```bash
kubectl get pods -n todoapp
# NAME                STATUS
# todoapp-backend-xxx Running
# todoapp-backend-yyy Pending    ← Stuck
```

**Diagnóstico**:

```bash
# Ver razón del Pending
kubectl describe pod todoapp-backend-yyy -n todoapp | grep -A 5 Events

# Salida típica:
# Events:
#   Type     Reason            Message
#   ----     ------            -------
#   Warning  FailedScheduling  0/2 nodes are available: 2 Insufficient cpu.
```

**Significado**: No hay nodos con CPU suficiente → **Cluster Autoscaler debería actuar**

**Verificar CA**:
```bash
# Ver logs de Cluster Autoscaler
kubectl logs -n kube-system -l k8s-app=cluster-autoscaler --tail=50

# Ver eventos
kubectl get events -n kube-system | grep cluster-autoscaler
```

**Si CA no actúa**: Verificar configuración del cluster
```bash
gcloud container clusters describe todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --format="value(autoscaling)"

# Debe mostrar:
# Autoscaling profile: BALANCED
# Enabled: True
# Min nodes: 2
# Max nodes: 10
```

### Problema 4: Demasiados Generadores (Cleanup)

**Síntoma**: Cluster con 20+ pods de carga, difícil de limpiar

**Solución**:

```bash
# Eliminar todos los pods que empiecen con "load-gen"
kubectl delete pod -n todoapp -l run=load-gen-1

# O con grep
kubectl get pods -n todoapp | grep load-gen | awk '{print $1}' | xargs kubectl delete pod -n todoapp

# O todos los pods tipo busybox
kubectl delete pod -n todoapp --field-selector=spec.containers[*].image=busybox
```

---

## Conclusión

### Componentes Clave

| Componente | Ubicación | Función |
|------------|-----------|---------|
| **Endpoint `/stress`** | `backend/server.js` | Genera CPU intensivo |
| **Pods BusyBox** | Creados con `kubectl run` | Llaman al endpoint repetidamente |
| **Scripts** | `load-testing/*.sh` | Automatizan generación de carga |

### Flujo de Generación de Carga

```
Crear Pods BusyBox → wget loop → /stress endpoint → CPU 100%
                                                         ↓
                                            metrics-server detecta
                                                         ↓
                                                HPA escala pods
                                                         ↓
                                            Pods Pending (si no caben)
                                                         ↓
                                            Cluster Autoscaler añade nodos
```

### Comandos Esenciales

```bash
# Generar carga
for i in {1..5}; do kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"; done

# Monitorear
watch kubectl get hpa -n todoapp

# Detener carga
kubectl delete pod -n todoapp -l run=load-gen-1
```

Esta configuración permite demostrar autoscaling de manera **predecible**, **observable** y **reproducible**.
