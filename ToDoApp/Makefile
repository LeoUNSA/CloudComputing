# Makefile para TodoApp Kubernetes

.PHONY: help setup deploy install-prometheus clean status logs shell

# Variables
NAMESPACE=todoapp
MONITORING_NS=monitoring
CLUSTER_NAME=todoapp-cluster

help: ## Mostrar esta ayuda
	@echo "TodoApp Kubernetes - Comandos disponibles:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Configurar Kind cluster y construir imágenes
	@echo "🚀 Configurando Kind cluster..."
	./scripts/setup.sh

deploy: ## Desplegar aplicación con Helm (sin monitoreo)
	@echo "📦 Desplegando aplicación..."
	kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install todoapp ./helm/todoapp -n todoapp --set monitoring.enabled=false

deploy-with-monitoring: ## Desplegar aplicación con monitoreo (requiere Prometheus instalado)
	@echo "📦 Desplegando aplicación con monitoreo..."
	kubectl create namespace todoapp --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install todoapp ./helm/todoapp -n todoapp --set monitoring.enabled=true

install-prometheus: ## Instalar Prometheus y Grafana
	@echo "📊 Instalando Prometheus..."
	./scripts/install-prometheus.sh

full-deploy: ## Despliegue completo (setup + deploy + prometheus) en orden correcto
	@echo "🚀 Despliegue completo con orden correcto..."
	./scripts/full-deploy.sh

status: ## Ver estado de todos los recursos
	@echo "📊 Estado del cluster:"
	@kubectl get nodes
	@echo
	@echo "📱 Estado de TodoApp:"
	@kubectl get all -n $(NAMESPACE) 2>/dev/null || echo "Namespace todoapp no existe"
	@echo
	@echo "📈 Estado de Monitoring:"
	@kubectl get all -n $(MONITORING_NS) 2>/dev/null || echo "Namespace monitoring no existe"

logs: ## Ver logs de la aplicación
	@echo "📋 Logs del Backend:"
	@kubectl logs -l app.kubernetes.io/component=backend -n $(NAMESPACE) --tail=20
	@echo
	@echo "📋 Logs del Frontend:"
	@kubectl logs -l app.kubernetes.io/component=frontend -n $(NAMESPACE) --tail=20

logs-backend: ## Ver logs del backend
	kubectl logs -l app.kubernetes.io/component=backend -n $(NAMESPACE) -f

logs-frontend: ## Ver logs del frontend
	kubectl logs -l app.kubernetes.io/component=frontend -n $(NAMESPACE) -f

logs-postgres: ## Ver logs de PostgreSQL
	kubectl logs -l app.kubernetes.io/component=postgres -n $(NAMESPACE) -f

shell-backend: ## Abrir shell en pod del backend
	kubectl exec -it deployment/todoapp-backend -n $(NAMESPACE) -- /bin/sh

shell-postgres: ## Abrir shell en pod de PostgreSQL
	kubectl exec -it deployment/todoapp-postgres -n $(NAMESPACE) -- psql -U postgres -d tasksdb

port-forward: ## Configurar port forwarding para desarrollo
	@echo "🌐 Configurando port forwarding..."
	@echo "Frontend: http://localhost:3000"
	@echo "Backend: http://localhost:5000"
	@echo "Presiona Ctrl+C para detener"
	kubectl port-forward svc/todoapp-frontend 3000:3000 -n $(NAMESPACE) &
	kubectl port-forward svc/todoapp-backend 5000:5000 -n $(NAMESPACE)

port-forward-prometheus: ## Port forward para Prometheus UI
	@echo "🔍 Prometheus UI: http://localhost:9090"
	kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n $(MONITORING_NS)

port-forward-grafana: ## Port forward para Grafana (alternativo)
	@echo "📊 Grafana: http://localhost:3001 (admin/admin123)"
	kubectl port-forward svc/prometheus-grafana 3001:80 -n $(MONITORING_NS)

test: ## Probar la aplicación
	@echo "🧪 Probando endpoints..."
	@echo "Testing backend health:"
	@curl -s http://localhost:30001/health || echo "Backend no disponible"
	@echo
	@echo "Testing frontend:"
	@curl -s -I http://localhost:30000 | head -1 || echo "Frontend no disponible"

restart: ## Reiniciar deployments
	kubectl rollout restart deployment -n $(NAMESPACE)

scale-up: ## Escalar aplicación (más réplicas)
	kubectl scale deployment todoapp-backend --replicas=3 -n $(NAMESPACE)
	kubectl scale deployment todoapp-frontend --replicas=3 -n $(NAMESPACE)

scale-down: ## Escalar aplicación (menos réplicas)
	kubectl scale deployment todoapp-backend --replicas=1 -n $(NAMESPACE)
	kubectl scale deployment todoapp-frontend --replicas=1 -n $(NAMESPACE)

update: ## Actualizar aplicación con nuevas imágenes
	@echo "🔄 Reconstruyendo imágenes..."
	docker build -t todoapp-backend:latest ./backend
	docker build -t todoapp-frontend:latest ./frontend
	kind load docker-image todoapp-backend:latest --name $(CLUSTER_NAME)
	kind load docker-image todoapp-frontend:latest --name $(CLUSTER_NAME)
	kubectl rollout restart deployment -n $(NAMESPACE)

clean: ## Limpiar todos los recursos (ELIMINA DATOS)
	@echo "🧹 Limpieza completa (elimina cluster y datos)..."
	./scripts/cleanup.sh

soft-stop: ## Parar aplicación manteniendo cluster y datos
	@echo "🔄 Parando aplicación (manteniendo datos)..."
	./scripts/soft-stop.sh

backup: ## Crear backup de los datos de PostgreSQL
	@echo "💾 Creando backup de datos..."
	./scripts/backup-data.sh

restore: ## Restaurar datos desde backup (requiere archivo como parámetro)
	@echo "📥 Para restaurar: make restore BACKUP=./backups/archivo.sql"
	@echo "Uso: ./scripts/restore-backup.sh ./backups/todoapp_backup_YYYYMMDD_HHMMSS.sql"

urls: ## Mostrar URLs de acceso
	@echo "🌐 URLs de acceso:"
	@echo "  Frontend: http://localhost:30000"
	@echo "  Backend: http://localhost:30001"
	@echo "  Grafana: http://localhost:30002 (admin/admin123)"
	@echo
	@echo "🔗 Port forwarding alternativo:"
	@echo "  make port-forward          # Frontend y Backend"
	@echo "  make port-forward-prometheus # Prometheus UI"
	@echo "  make port-forward-grafana   # Grafana alternativo"

monitoring: ## Ver recursos de monitoreo
	@echo "📈 Recursos de Prometheus:"
	@kubectl get all -n $(MONITORING_NS)
	@echo
	@echo "🔧 ServiceMonitors:"
	@kubectl get servicemonitor -n $(NAMESPACE)

# Comandos de desarrollo
dev-setup: ## Configuración para desarrollo local
	@echo "🛠️  Configurando entorno de desarrollo..."
	kind create cluster --config=k8s/kind-config.yaml
	docker build -t todoapp-backend:latest ./backend
	docker build -t todoapp-frontend:latest ./frontend
	kind load docker-image todoapp-backend:latest --name $(CLUSTER_NAME)
	kind load docker-image todoapp-frontend:latest --name $(CLUSTER_NAME)

dev-deploy: ## Despliegue rápido para desarrollo
	helm upgrade --install todoapp ./helm/todoapp -n $(NAMESPACE) --create-namespace

# Comandos de Helm
helm-template: ## Ver template de Helm generado
	helm template todoapp ./helm/todoapp -n $(NAMESPACE)

helm-lint: ## Validar chart de Helm
	helm lint ./helm/todoapp

helm-values: ## Ver valores actuales de Helm
	helm get values todoapp -n $(NAMESPACE)

# Información del sistema
info: ## Información del cluster
	@echo "ℹ️  Información del Cluster:"
	@kubectl cluster-info --context kind-$(CLUSTER_NAME)
	@echo
	@kubectl get nodes
	@echo
	@kubectl version --short