# Test Manual de Autoscaling - Guía Simplificada

## Objetivo

Demostrar el autoscaling tanto a nivel de **pods (HPA)** como de **nodos (Cluster Autoscaler)** con comandos mínimos.

---

## Pre-requisitos

✅ Aplicación desplegada en GKE  
✅ `kubectl` configurado  
✅ Namespace `todoapp` existente  

### Verificación Rápida

```bash
kubectl get nodes
kubectl get hpa -n todoapp
```

---

## Paso 1: Ver Estado Inicial

### Comando

```bash
kubectl get hpa -n todoapp && echo && kubectl get nodes && echo && kubectl get pods -n todoapp
```

### Salida Esperada

```
NAME                  REFERENCE                  TARGETS    MINPODS   MAXPODS   REPLICAS
todoapp-backend-hpa   Deployment/todoapp-backend 2%/50%     2         10        2

NAME                                       STATUS   ROLES    AGE
gke-...-default-pool-abc123                Ready    <none>   15m
gke-...-default-pool-def456                Ready    <none>   15m

NAME                               READY   STATUS    RESTARTS   AGE
todoapp-backend-xxx                1/1     Running   0          10m
todoapp-backend-yyy                1/1     Running   0          10m
todoapp-frontend-zzz               1/1     Running   0          10m
```

**Resumen**:
- 🟢 **2 pods backend** (mínimo)
- 🟢 **2 nodos** en cluster
- 🟢 **CPU: 2%** (muy bajo)

---

## Paso 2: Generar Carga

### Comando (Single Line)

```bash
kubectl run load-gen-1 --image=busybox --restart=Never -n todoapp -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
```

### Para Mayor Carga (Opcional)

```bash
# Crear 5 generadores de carga
for i in {1..5}; do
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
done
```

**Qué hace**:
- Llama al endpoint `/stress` del backend
- Genera CPU intensivo por 40 segundos
- Loop infinito (carga continua)

---

## Paso 3: Monitorear Escalado

### Comando (Terminal 1)

```bash
watch -n 2 'kubectl get hpa -n todoapp'
```

### Salida (Evolución)

```
T+0s:   TARGETS: 2%/50%     REPLICAS: 2

T+30s:  TARGETS: 75%/50%    REPLICAS: 2  ← CPU sube

T+1min: TARGETS: 95%/50%    REPLICAS: 4  ← HPA escala

T+2min: TARGETS: 85%/50%    REPLICAS: 6

T+3min: TARGETS: 80%/50%    REPLICAS: 8

T+4min: TARGETS: 88%/50%    REPLICAS: 10 ← Máximo alcanzado
```

### Comando (Terminal 2)

```bash
watch -n 2 'kubectl get pods -n todoapp -l app=todoapp-backend'
```

### Salida (Evolución)

```
T+0s:   2 pods Running

T+1min: 4 pods (2 Running, 2 ContainerCreating)

T+2min: 6 pods Running

T+3min: 8 pods Running

T+4min: 10 pods (9 Running, 1 Pending) ← Falta recursos
```

**⚠️ Punto clave**: Pod en estado **Pending** = necesita más nodos

---

## Paso 4: Cluster Autoscaler en Acción

### Comando (Terminal 3)

```bash
watch -n 5 'kubectl get nodes'
```

### Salida (Evolución)

```
T+0s:   2 nodos Ready

T+4min: 2 nodos Ready (pod aún Pending)

T+5min: 3 nodos (2 Ready, 1 NotReady) ← Nuevo nodo provisionándose

T+7min: 3 nodos Ready ← Nodo listo
```

### Ver Pod Asignado al Nuevo Nodo

```bash
kubectl get pods -n todoapp -l app=todoapp-backend -o wide
```

```
NAME                READY   STATUS    NODE
...
todoapp-backend-www 1/1     Running   gke-...-ghi789  ← Nodo 3 (nuevo)
```

---

## Paso 5: Eliminar Carga

### Comando

```bash
# Eliminar todos los generadores de carga
kubectl delete pod -l run=load-gen-1 -n todoapp

# O específicamente
for i in {1..5}; do
  kubectl delete pod load-gen-$i -n todoapp --ignore-not-found
done
```

---

## Paso 6: Observar Scale-Down

### HPA Scale-Down

```bash
watch -n 5 'kubectl get hpa -n todoapp'
```

```
T+0s (carga eliminada):  TARGETS: 85%/50%    REPLICAS: 10

T+1min:                  TARGETS: 25%/50%    REPLICAS: 10  ← HPA espera (stabilization)

T+5min:                  TARGETS: 2%/50%     REPLICAS: 10  ← Aún esperando

T+6min:                  TARGETS: 1%/50%     REPLICAS: 8   ← Empieza scale-down

T+8min:                  TARGETS: 1%/50%     REPLICAS: 6

T+10min:                 TARGETS: 1%/50%     REPLICAS: 4

T+12min:                 TARGETS: 2%/50%     REPLICAS: 2   ← Vuelve al mínimo
```

**⏱️ Tiempo total**: ~12 minutos (debido a `stabilizationWindowSeconds: 300`)

### Cluster Autoscaler Scale-Down

```bash
watch -n 10 'kubectl get nodes'
```

```
T+0s:   3 nodos Ready

T+10min: 3 nodos Ready (esperando utilización baja)

T+20min: 3 nodos Ready (nodo 3 con baja carga)

T+30min: 2 nodos Ready ← Nodo 3 eliminado
```

**⏱️ Tiempo total**: ~30 minutos (Cluster Autoscaler es conservador)

---

## Resumen de Comandos (Copy-Paste)

### Setup Inicial

```bash
# Ver estado
kubectl get hpa -n todoapp && kubectl get nodes && kubectl get pods -n todoapp
```

### Generar Carga

```bash
# Carga ligera (1 generador)
kubectl run load-gen-1 --image=busybox --restart=Never -n todoapp -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"

# Carga fuerte (5 generadores)
for i in {1..5}; do kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"; done
```

### Monitoreo (3 Terminales)

```bash
# Terminal 1: HPA
watch -n 2 'kubectl get hpa -n todoapp'

# Terminal 2: Pods
watch -n 2 'kubectl get pods -n todoapp'

# Terminal 3: Nodos
watch -n 5 'kubectl get nodes'
```

### Eliminar Carga

```bash
# Eliminar generadores
kubectl delete pod -n todoapp --selector=run=load-gen-1
for i in {1..5}; do kubectl delete pod load-gen-$i -n todoapp --ignore-not-found; done
```

---

## Timeline Completo de la Demo

```
┌─────────────────────────────────────────────────────────────────┐
│  FASE 1: SCALE-UP (0-5 minutos)                                 │
└─────────────────────────────────────────────────────────────────┘

T=0:     2 pods, 2 nodos, CPU 2%
         ↓
         Generar carga (5 pods busybox)
         ↓
T=30s:   CPU sube a 75%
         ↓
T=1min:  HPA escala: 2 → 4 pods
         ↓
T=2min:  HPA escala: 4 → 6 pods
         ↓
T=3min:  HPA escala: 6 → 8 pods
         ↓
T=4min:  HPA escala: 8 → 10 pods (máximo)
         ↓
         1 pod queda "Pending" (no hay recursos)
         ↓
T=5min:  Cluster Autoscaler añade nodo 3
         ↓
T=7min:  Nodo 3 listo, pod Pending → Running
         ↓
         Estado final: 10 pods, 3 nodos, CPU 85%

┌─────────────────────────────────────────────────────────────────┐
│  FASE 2: SCALE-DOWN (5-40 minutos)                              │
└─────────────────────────────────────────────────────────────────┘

T=8min:  Eliminar carga
         ↓
T=9min:  CPU baja a 5%
         ↓
T=10min: HPA espera (stabilizationWindow)
         ↓
T=14min: HPA escala: 10 → 8 pods
         ↓
T=16min: HPA escala: 8 → 6 pods
         ↓
T=18min: HPA escala: 6 → 4 pods
         ↓
T=20min: HPA escala: 4 → 2 pods (mínimo)
         ↓
         Nodo 3 queda con baja carga
         ↓
T=30min: Cluster Autoscaler espera 10 min
         ↓
T=40min: Cluster Autoscaler elimina nodo 3
         ↓
         Estado final: 2 pods, 2 nodos, CPU 2% (estado inicial)
```

---

## Métricas Clave a Observar

| Métrica | Comando | Qué Buscar |
|---------|---------|------------|
| **CPU Pods** | `kubectl top pods -n todoapp` | > 50% → scale-up |
| **Réplicas HPA** | `kubectl get hpa -n todoapp` | REPLICAS aumenta |
| **Pods Pending** | `kubectl get pods -n todoapp` | STATUS: Pending |
| **Número Nodos** | `kubectl get nodes` | Incrementa de 2 → 3 |
| **Distribución Pods** | `kubectl get pods -n todoapp -o wide` | NODE columna |

---

## Troubleshooting Rápido

### HPA No Escala

```bash
# Verificar metrics-server
kubectl top pods -n todoapp

# Si falla, reinstalar
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}
```

### Cluster Autoscaler No Añade Nodo

```bash
# Ver eventos
kubectl get events -n kube-system | grep cluster-autoscaler

# Verificar configuración
gcloud container clusters describe todoapp-autoscaling-cluster \
  --zone=us-central1-a \
  --format="value(autoscaling)"
```

### Pods No Generan Carga

```bash
# Verificar logs del generador
kubectl logs load-gen-1 -n todoapp

# Verificar backend está funcionando
kubectl logs -l app=todoapp-backend -n todoapp --tail=20
```

---

## Conclusión

Esta demo muestra:

✅ **HPA**: Escala pods de 2 → 10 en ~4 minutos  
✅ **Cluster Autoscaler**: Añade nodo cuando pods quedan Pending  
✅ **Scale-Down**: Ambos reducen recursos cuando demanda baja  

**Tiempos**:
- Scale-up: **Rápido** (segundos para HPA, 2-3 min para nodos)
- Scale-down: **Conservador** (5 min HPA, 10+ min Cluster Autoscaler)

**Comandos mínimos**:
1. Generar carga: `kubectl run load-gen-1 ...`
2. Monitorear: `watch kubectl get hpa -n todoapp`
3. Eliminar carga: `kubectl delete pod load-gen-1 -n todoapp`

**Duración total demo**: ~10 minutos para scale-up, ~30 minutos para ver scale-down completo.
