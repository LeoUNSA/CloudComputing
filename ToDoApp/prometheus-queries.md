# 📊 EJEMPLOS DE CONSULTAS PROMETHEUS PARA TODOAPP

## 🔍 1. ESTADO DE LA APLICACIÓN
# ¿Están todos mis servicios funcionando?
up{job="kube-state-metrics"}

# ¿Cuántos pods están corriendo por componente?
kube_pod_status_phase{namespace="todoapp"}

## 📈 2. RENDIMIENTO Y RECURSOS
# Uso de CPU por pod de TodoApp
rate(container_cpu_usage_seconds_total{namespace="todoapp"}[5m])

# Uso de memoria por pod
container_memory_usage_bytes{namespace="todoapp"}

# Tráfico de red
rate(container_network_receive_bytes_total{namespace="todoapp"}[5m])

## 🚨 3. ALERTAS Y PROBLEMAS
# Pods que han reiniciado recientemente
increase(kube_pod_container_status_restarts_total{namespace="todoapp"}[1h])

# Pods que no están listos
kube_pod_status_ready{namespace="todoapp", condition="false"}

# Uso de memoria cerca del límite
(container_memory_usage_bytes{namespace="todoapp"} / container_spec_memory_limit_bytes{namespace="todoapp"}) * 100 > 80

## 📊 4. MÉTRICAS DE NEGOCIO (cuando agregues instrumentación)
# Requests por minuto a la API
rate(http_requests_total{service="todoapp-backend"}[1m]) * 60

# Tareas creadas por hora
rate(tasks_created_total[1h]) * 3600

# Tiempo promedio de respuesta
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service="todoapp-backend"}[5m]))

## 🗄️ 5. BASE DE DATOS
# Conexiones activas a PostgreSQL
pg_stat_activity_count{namespace="todoapp"}

# Tamaño de la base de datos
pg_database_size_bytes{namespace="todoapp"}

# Queries por segundo
rate(pg_stat_database_tup_returned{namespace="todoapp"}[5m])