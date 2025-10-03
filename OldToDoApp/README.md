# 📝 Gestor de Tareas - Aplicación Web con Docker

Una aplicación web funcional para gestión de tareas desarrollada con arquitectura de microservicios usando Docker. La aplicación consta de 3 contenedores independientes: frontend (React), backend (Node.js/Express) y base de datos (PostgreSQL).

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│    Frontend     │────│     Backend     │────│   PostgreSQL    │
│   (React)       │    │ (Node.js/API)   │    │   (Database)    │
│   Puerto: 3000  │    │   Puerto: 5000  │    │   Puerto: 5432  │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Características

- ✅ **Frontend React**: Interfaz de usuario moderna y responsiva
- ✅ **API REST**: Backend con Node.js y Express
- ✅ **Base de datos PostgreSQL**: Persistencia de datos confiable
- ✅ **Contenedores Docker**: Cada servicio en su propio contenedor
- ✅ **Docker Compose**: Orquestación automática de servicios
- ✅ **Funcionalidades completas**: Crear, leer, actualizar y eliminar tareas
- ✅ **Datos de ejemplo**: Tareas precargadas para probar la aplicación

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

## 📄 Licencia

Este proyecto es de ejemplo y está disponible bajo la licencia MIT.

---

