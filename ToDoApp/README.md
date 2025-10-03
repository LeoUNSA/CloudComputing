# 📝 TodoApp - Gestor de Tareas Empresarial en Kubernetes

## � Descripción

**TodoApp** es una aplicación web moderna de gestión de tareas desarrollada con arquitectura de microservicios, desplegada en Kubernetes utilizando las mejores prácticas de la industria. La aplicación permite a los usuarios crear, gestionar, completar y eliminar tareas de manera eficiente, proporcionando una interfaz web intuitiva respaldada por una API REST robusta y una base de datos PostgreSQL persistente.

### 🎯 Características Principales

- ✅ **Interfaz moderna**: Frontend React con diseño responsivo
- ✅ **API REST completa**: Backend Node.js/Express con operaciones CRUD
- ✅ **Persistencia garantizada**: Base de datos PostgreSQL con volúmenes persistentes
- ✅ **Arquitectura en contenedores**: Microservicios independientes y escalables
- ✅ **Orquestación profesional**: Despliegue en Kubernetes con Helm
- ✅ **Monitoreo avanzado**: Observabilidad completa con Prometheus y Grafana
- ✅ **Alta disponibilidad**: Múltiples réplicas y autorecuperación

### 🌐 URLs de Acceso

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Frontend Web** | http://localhost:30000 | - |
| **API REST** | http://localhost:30001 | - |
| **Grafana (Monitoreo)** | http://localhost:30002 | admin/admin123 |
| **Prometheus** | http://localhost:9091 | - |

---

## 🏗️ Descripción de Microservicios

La aplicación TodoApp está diseñada siguiendo principios de microservicios, lo que garantiza escalabilidad, mantenibilidad y tolerancia a fallos.

### 🎯 Frontend Service (React + Nginx)

**Tecnología**: React 18 + Nginx Alpine
```yaml
Réplicas: 2 (Alta Disponibilidad)
Recursos: 100m CPU, 128Mi RAM por réplica
Puerto: 3000 (Expuesto como NodePort 30000)
```

**Responsabilidades**:
- 🖥️ Interfaz de usuario responsiva
- 🔄 Gestión de estado local (React Hooks)
- 🌐 Comunicación con API backend
- 📱 Experiencia de usuario optimizada

**Escalabilidad**:
- **Horizontal**: Autoescalado basado en CPU (HPA)
- **Stateless**: Sin persistencia local, permitiendo escalado ilimitado
- **CDN Ready**: Archivos estáticos servidos por Nginx optimizado
- **Load Balancing**: Kubernetes distribuye tráfico automáticamente

### 🔧 Backend Service (Node.js/Express)

**Tecnología**: Node.js 18 + Express
```yaml
Réplicas: 2 (Balanceador de carga)
Recursos: 200m CPU, 256Mi RAM por réplica
Puerto: 5000 (Expuesto como NodePort 30001)
```

**Responsabilidades**:
- 📡 API REST con endpoints CRUD
- 🔐 Validación de datos y lógica de negocio
- 🗄️ Gestión de conexiones a base de datos
- 📊 Exposición de métricas para monitoreo

**Escalabilidad**:
- **Horizontal**: Escalado automático basado en requests/CPU
- **Stateless**: Conexiones de BD pooled, sin sesiones locales
- **Circuit Breaker**: Tolerancia a fallos en conexiones BD
- **Health Checks**: Autorecuperación ante fallos

**Endpoints API**:
```javascript
GET    /tasks           // Obtener todas las tareas
POST   /tasks           // Crear nueva tarea
PUT    /tasks/:id       // Actualizar tarea existente
DELETE /tasks/:id       // Eliminar tarea
GET    /health          // Health check
GET    /metrics         // Métricas Prometheus
```

### 🗄️ Database Service (PostgreSQL)

**Tecnología**: PostgreSQL 15 Alpine
```yaml
Réplicas: 1 (Master único con persistencia)
Recursos: 500m CPU, 512Mi RAM
Volumen: 1Gi PersistentVolume
```

**Responsabilidades**:
- 💾 Almacenamiento persistente de tareas
- 🔄 Transacciones ACID garantizadas
- 📊 Optimización de consultas
- 🛡️ Integridad referencial

**Escalabilidad**:
- **Vertical**: Incremento de CPU/RAM según demanda
- **Read Replicas**: Réplicas de lectura para consultas
- **Connection Pooling**: PgBouncer para optimizar conexiones
- **Backup/Restore**: Estrategias de respaldo automatizadas

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

### � Monitoring Stack (Prometheus + Grafana)

**Tecnología**: Prometheus + Grafana + AlertManager
```yaml
Componentes: 8 pods de monitoreo
Almacenamiento: 5Gi para métricas, 1Gi para Grafana
Retención: 7 días de métricas históricas
```

**Responsabilidades**:
- 📈 Recolección de métricas en tiempo real
- 🎨 Visualización con dashboards interactivos
- 🚨 Sistema de alertas automatizado
- 📊 Análisis de rendimiento y capacidad

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

### � Beneficios de la Combinación

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

### 🛑 **FINALIZAR TODO (Limpieza Completa)**
```bash
# 🧹 Eliminar aplicación y cluster
make clean
```

> 📋 **Guía completa de comandos**: Ver [`COMANDOS.md`](COMANDOS.md) para comandos detallados, troubleshooting y mejores prácticas.

## 📊 Arquitectura de Despliegue

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │   PostgreSQL    │
│   (React)       │────│   (Node.js)     │────│   (Database)    │
│   2 réplicas    │    │   2 réplicas    │    │   1 réplica     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Prometheus    │
                    │   + Grafana     │
                    │   (8 pods)      │
                    └─────────────────┘
```

## 🎯 Roadmap Futuro

- [ ] **CI/CD Pipeline**: GitHub Actions + ArgoCD
- [ ] **Service Mesh**: Istio para microservicios avanzados
- [ ] **Autenticación**: OAuth2/JWT con Keycloak
- [ ] **Cache Layer**: Redis para optimización
- [ ] **Message Queue**: RabbitMQ para procesamiento asíncrono
- [ ] **Multi-cloud**: AWS EKS + Azure AKS deployment

---

**Desarrollado con ❤️ usando las mejores prácticas de Cloud Native**

## 📁 Estructura del Proyecto

```
dockerapp/
├── backend/                 # API REST con Node.js
│   ├── server.js           # Servidor principal
│   ├── package.json        # Dependencias del backend
│   ├── Dockerfile          # Imagen Docker del backend
│   └── .env               # Variables de entorno
├── frontend/               # Aplicación React
│   ├── src/
│   │   ├── App.js         # Componente principal
│   │   ├── index.js       # Punto de entrada
│   │   └── index.css      # Estilos CSS
│   ├── public/
│   │   └── index.html     # HTML base
│   ├── package.json       # Dependencias del frontend
│   └── Dockerfile         # Imagen Docker del frontend
├── database/               # Configuración de PostgreSQL
│   └── init.sql           # Script de inicialización de la BD
├── docker-compose.yml      # Orquestación de contenedores
├── .dockerignore          # Archivos a ignorar en Docker
└── README.md              # Este archivo
```

## ⚡ Inicio Rápido

### Prerrequisitos

- [Docker](https://www.docker.com/get-started) instalado
- [Docker Compose](https://docs.docker.com/compose/install/) instalado

### Instalación y Ejecución

1. **Clona o descarga el proyecto**
   ```bash
   cd /home/leo/dockerapp
   ```

2. **Construye y ejecuta todos los contenedores**
   ```bash
   docker-compose up --build
   ```

3. **Accede a la aplicación**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:5000
   - Base de datos: localhost:5432

### Comandos Útiles

```bash
# Ejecutar en segundo plano
docker-compose up -d

# Ver logs de todos los servicios
docker-compose logs

# Ver logs de un servicio específico
docker-compose logs backend
docker-compose logs frontend
docker-compose logs database

# Parar todos los contenedores
docker-compose down

# Parar y eliminar volúmenes (¡cuidado, se pierden los datos!)
docker-compose down -v

# Reconstruir imágenes
docker-compose build

# Reconstruir sin cache
docker-compose build --no-cache
```

## 🔧 Configuración

### Variables de Entorno

El backend utiliza las siguientes variables de entorno (configuradas en `backend/.env`):

```env
PORT=5000
DB_HOST=database
DB_PORT=5432
DB_NAME=tasksdb
DB_USER=postgres
DB_PASSWORD=postgres
```

### Puertos Utilizados

- **3000**: Frontend React
- **5000**: Backend API REST
- **5432**: Base de datos PostgreSQL

## 📊 API Endpoints

La API REST proporciona los siguientes endpoints:

### Tareas

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/tasks` | Obtener todas las tareas |
| POST | `/tasks` | Crear una nueva tarea |
| PUT | `/tasks/:id` | Actualizar una tarea existente |
| DELETE | `/tasks/:id` | Eliminar una tarea |

### Salud del Servicio

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/health` | Verificar estado de la API |

### Ejemplo de Uso de la API

```bash
# Obtener todas las tareas
curl http://localhost:5000/tasks

# Crear una nueva tarea
curl -X POST http://localhost:5000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Mi nueva tarea","description":"Descripción de la tarea"}'

# Marcar tarea como completada
curl -X PUT http://localhost:5000/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"Mi tarea","description":"Descripción","completed":true}'

# Eliminar una tarea
curl -X DELETE http://localhost:5000/tasks/1
```

## 🛠️ Desarrollo

### Desarrollo Local (sin Docker)

Si prefieres desarrollar sin Docker:

1. **Backend:**
   ```bash
   cd backend
   npm install
   npm run dev  # Usa nodemon para hot reload
   ```

2. **Frontend:**
   ```bash
   cd frontend
   npm install
   npm start    # Servidor de desarrollo React
   ```

3. **Base de datos:**
   Instala PostgreSQL localmente y ejecuta el script `database/init.sql`

### Modificaciones y Hot Reload

Los contenedores están configurados con volúmenes para desarrollo:
- Los cambios en el código se reflejan automáticamente
- No necesitas reconstruir las imágenes durante el desarrollo

## 📝 Funcionalidades de la Aplicación

### Frontend (React)
- Interfaz intuitiva para gestión de tareas
- Formulario para crear nuevas tareas
- Lista de tareas con estado visual
- Marcar tareas como completadas
- Eliminar tareas
- Manejo de errores y estados de carga

### Backend (Node.js/Express)
- API REST completa
- Validación de datos
- Manejo de errores
- Conexión a PostgreSQL
- CORS habilitado para frontend

### Base de Datos (PostgreSQL)
- Tabla de tareas con campos: id, título, descripción, completado, timestamps
- Datos de ejemplo precargados
- Triggers automáticos para timestamps
- Persistencia de datos con volúmenes Docker

## 🐛 Solución de Problemas

### Los contenedores no se conectan
- Verifica que todos los contenedores estén ejecutándose: `docker-compose ps`
- Revisa los logs: `docker-compose logs`

### Error de conexión a la base de datos
- Espera a que PostgreSQL esté listo (usa health checks)
- Verifica las credenciales en las variables de entorno

### Cambios no se reflejan
- Para cambios en package.json: `docker-compose build`
- Para cambios en Dockerfile: `docker-compose build --no-cache`

### Puerto ocupado
- Cambia los puertos en `docker-compose.yml` si están ocupados
- Verifica procesos usando los puertos: `lsof -i :3000`

## 🚀 Próximos Pasos

Ideas para expandir la aplicación:

- [ ] Autenticación de usuarios
- [ ] Categorías de tareas
- [ ] Fechas de vencimiento
- [ ] Notificaciones
- [ ] Tests automatizados
- [ ] CI/CD pipeline
- [ ] Deployment en producción

## 📄 Licencia

Este proyecto es de ejemplo y está disponible bajo la licencia MIT.

---

¡Felicidades! 🎉 Tienes una aplicación web completa funcionando con Docker. Explora el código, modifica las funcionalidades y aprende sobre arquitectura de microservicios.
