# 🚀 Guía de Comandos - TodoApp Kubernetes

## ⚡ INICIO RÁPIDO (Orden Recomendado)

### 1️⃣ **INICIAR LA APLICACIÓN COMPLETA**

```bash
# 🎯 COMANDO PRINCIPAL - Todo en uno
make full-deploy

# ✅ Esto ejecuta automáticamente:
# 1. Verificar dependencias (Docker, Kind, kubectl, Helm)
# 2. Crear cluster Kind con configuración optimizada
# 3. Construir imágenes Docker (frontend y backend)
# 4. Cargar imágenes en Kind
# 5. Desplegar aplicación con Helm
# 6. Instalar Prometheus y Grafana
# 7. Habilitar monitoreo
```

### 2️⃣ **VERIFICAR QUE TODO FUNCIONA**

```bash
# 📊 Ver estado general
make status

# 🔍 Validación completa automática
./scripts/validate.sh

# 📋 Ver logs si hay problemas
make logs
```

### 3️⃣ **ACCEDER A LA APLICACIÓN**

```bash
# 🌐 Mostrar URLs disponibles
make urls

# URLs principales:
# Frontend: http://localhost:30000
# Backend:  http://localhost:30001
# Grafana:  http://localhost:30002 (admin/admin123)
```

---

## 🔧 COMANDOS DETALLADOS (Paso a Paso)

### 🏗️ **INICIO MANUAL (Si prefieres control total)**

```bash
# 1. Configurar cluster y construir imágenes
make setup

# 2. Desplegar solo la aplicación (sin monitoreo)
make deploy

# 3. Instalar monitoreo (opcional)
make install-prometheus

# 4. Habilitar monitoreo en la app
make deploy-with-monitoring
```

### 📊 **OPERACIÓN Y MONITOREO**

```bash
# Ver estado detallado
export KUBECONFIG=/tmp/kubeconfig
kubectl get all -n todoapp
kubectl get all -n monitoring

# Ver logs en tiempo real
make logs-backend
make logs-frontend  
make logs-postgres

# Probar endpoints
make test

# Port forwarding para desarrollo
make port-forward
```

### 🔄 **ACTUALIZACIÓN Y MANTENIMIENTO**

```bash
# Actualizar con nuevas imágenes
make update

# Reiniciar servicios
make restart

# Escalar aplicación
make scale-up    # Más réplicas
make scale-down  # Menos réplicas
```

---

## 🛑 FINALIZACIÓN SEGURA

### 🔄 **PARADA SUAVE (MANTIENE DATOS) - RECOMENDADA**

```bash
# ✅ OPCIÓN RECOMENDADA - Mantiene datos
make soft-stop

# Para reiniciar (datos persisten automáticamente)
make deploy              # Solo aplicación
make full-deploy        # Aplicación + Prometheus
```

### 💾 **BACKUP Y RESTORE (Para limpieza completa)**

```bash
# 1. Crear backup antes de limpiar
make backup

# 2. Limpieza completa
make clean

# 3. Redesplegar
make full-deploy

# 4. Restaurar datos
./scripts/restore-backup.sh ./backups/todoapp_backup_YYYYMMDD_HHMMSS.sql
```

### 🧹 **PARADA COMPLETA Y LIMPIEZA (ELIMINA DATOS)**

```bash
# ⚠️ COMANDO PRINCIPAL - Eliminación total
make clean

# ✅ Esto elimina:
# 1. Release de Helm de TodoApp
# 2. Stack de Prometheus completo
# 3. Namespaces (todoapp y monitoring)
# 4. Cluster de Kind completo
# 5. TODOS LOS DATOS ❌
```

### 🔄 **PARADA TEMPORAL (Sin eliminar cluster)**

```bash
# Solo desinstalar aplicación (mantener cluster)
helm uninstall todoapp -n todoapp
helm uninstall prometheus -n monitoring

# Eliminar namespaces
kubectl delete namespace todoapp
kubectl delete namespace monitoring
```

### ⚠️ **PARADA DE EMERGENCIA**

```bash
# Si algo no responde, forzar eliminación
sudo docker stop $(sudo docker ps -q)
sudo kind delete cluster --name todoapp-cluster

# Limpiar procesos colgados
sudo pkill -f "kubectl port-forward"
sudo pkill -f "kind"
```

---

## 🆘 SOLUCIÓN DE PROBLEMAS

### 🔍 **DIAGNÓSTICO RÁPIDO**

```bash
# 1. Verificar que Docker funciona
docker info

# 2. Verificar que el cluster existe
kind get clusters

# 3. Verificar conectividad
export KUBECONFIG=/tmp/kubeconfig
kubectl get nodes

# 4. Ver eventos del sistema
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

### 🛠️ **PROBLEMAS COMUNES Y SOLUCIONES**

```bash
# ❌ Error: "Docker daemon not running"
sudo systemctl start docker

# ❌ Error: "kind cluster not found" 
make setup

# ❌ Error: "kubectl context not found"
export KUBECONFIG=/tmp/kubeconfig

# ❌ Error: "pods not ready"
kubectl wait --for=condition=ready pod --all -n todoapp --timeout=300s

# ❌ Error: "port already in use"
sudo lsof -i :30000  # Ver qué usa el puerto
sudo pkill -f "kubectl port-forward"
```

### 🔄 **RESET COMPLETO (Empezar de cero)**

```bash
# 1. Parar todo
make clean

# 2. Limpiar Docker (opcional)
sudo docker system prune -f

# 3. Verificar que no hay procesos
ps aux | grep -E "(kind|kubectl|helm)"

# 4. Empezar de nuevo
make full-deploy
```

---

## 📋 COMANDOS DE REFERENCIA RÁPIDA

### ⚡ **INICIO**
```bash
make full-deploy     # ✅ RECOMENDADO - Todo automático
make setup          # Solo cluster e imágenes
make deploy         # Solo aplicación
```

### 📊 **ESTADO**
```bash
make status         # Estado general
make urls          # URLs de acceso
./scripts/validate.sh  # Validación completa
```

### 🔍 **LOGS Y DEBUG**
```bash
make logs          # Logs generales
make logs-backend  # Solo backend
make test          # Probar endpoints
```

### 🛑 **FINALIZACIÓN**
```bash
make clean         # ✅ RECOMENDADO - Limpieza total
helm uninstall todoapp -n todoapp  # Solo aplicación
```

### 🆘 **EMERGENCIA**
```bash
sudo kind delete cluster --name todoapp-cluster  # Forzar eliminación
sudo docker stop $(sudo docker ps -q)           # Parar todos containers
```

---

## 🎯 MEJORES PRÁCTICAS

### ✅ **ANTES DE INICIAR**
1. Asegurar que Docker esté corriendo
2. Cerrar otras aplicaciones que usen puertos 30000-30002
3. Tener al menos 4GB RAM disponibles

### ✅ **DURANTE OPERACIÓN**
1. Usar `make status` para verificar estado
2. Monitorear logs si hay comportamiento extraño
3. Usar Grafana para observabilidad visual

### ✅ **ANTES DE FINALIZAR**
1. Guardar datos importantes (si los hay)
2. Verificar que no hay procesos críticos
3. Usar `make clean` para limpieza completa

### ❌ **EVITAR**
- No usar `docker rm -f` directamente en containers de Kind
- No eliminar manualmente volúmenes de PostgreSQL sin backup
- No cambiar configuración de Kind mientras está corriendo