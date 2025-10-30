# ⚠️ IMPORTANTE: Configuración Post-Clonación

## 🚨 Problemas Identificados y Soluciones

### 1. Archivo `backend/.env` Trackeado en Git

**Problema**: El archivo `backend/.env` está siendo trackeado por git cuando debería estar en `.gitignore`.

**Impacto**: Si alguien clona el repositorio, el archivo vendrá con credenciales hardcodeadas (postgres/postgres).

**Solución Inmediata**:

```bash
# Paso 1: Remover del tracking de git SIN borrarlo localmente
git rm --cached backend/.env

# Paso 2: Commit del cambio
git add .gitignore backend/.env.example
git commit -m "fix: Remove backend/.env from git tracking, add .env.example"

# Paso 3: Push
git push
```

**Para nuevos usuarios que clonen después del fix**:

```bash
# Copiar el ejemplo
cp backend/.env.example backend/.env

# El archivo backend/.env ahora está en .gitignore y no se subirá
```

---

## 📋 Checklist de Archivos al Clonar

### Archivos que SÍ están en Git (✅ OK)

- ✅ `.env.example` - Plantilla de variables (raíz)
- ✅ `backend/.env.example` - Plantilla para backend
- ✅ `ansible/inventories/gcp/group_vars/all.yml` - Variables de Ansible
- ✅ Todo el código fuente (backend/, frontend/, helm/, etc.)
- ✅ Documentación completa en `docs/`

### Archivos que NO están en Git (🔒 Seguridad)

- 🔒 `.env` - Variables de entorno locales
- 🔒 `backend/.env` - Configuración del backend (AHORA en .gitignore)
- 🔒 `~/.gcp/credentials.json` - Credenciales de service account
- 🔒 `node_modules/` - Dependencias
- 🔒 `build/` - Builds compilados
- 🔒 `*.log` - Archivos de log

---

## 🛠️ Pasos OBLIGATORIOS Después de Clonar

### 1. Crear Archivo `.env` en Backend

```bash
# Copiar el ejemplo
cp backend/.env.example backend/.env

# Editar si necesitas cambiar valores
nano backend/.env
```

**Contenido por defecto**:
```bash
PORT=5000
DB_HOST=database           # Para Docker Compose local
DB_PORT=5432
DB_NAME=tasksdb
DB_USER=postgres
DB_PASSWORD=postgres       # OK para desarrollo, cambiar en producción
```

**Nota**: En GKE, estos valores se sobrescriben por ConfigMaps/Secrets del Helm chart, NO afectan al deployment en cloud.

### 2. Autenticación en GCP

```bash
# Opción A: Autenticación de usuario (más simple)
gcloud auth login
gcloud config set project <TU_PROJECT_ID>
gcloud auth configure-docker

# Opción B: Service account (CI/CD)
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials.json"
# (previamente creado según SETUP-GUIDE.md)
```

### 3. Editar Variables de Ansible

```bash
# Abrir archivo de configuración
nano ansible/inventories/gcp/group_vars/all.yml
```

**CAMBIAR OBLIGATORIAMENTE**:
```yaml
# Línea 3
gcp_project_id: "TU-PROYECTO-ID-AQUI"  # ← CAMBIAR
```

**Opcional** (usar valores por defecto si prefieres):
```yaml
gcp_region: "us-central1"              # OK
gcp_zone: "us-central1-a"              # OK
gke_cluster_name: "todoapp-autoscaling-cluster"  # OK
```

### 4. Vincular Billing

```bash
# Listar billing accounts
gcloud billing accounts list

# Vincular
gcloud billing projects link <TU_PROJECT_ID> \
  --billing-account=<BILLING_ACCOUNT_ID>
```

---

## 🔍 Verificación de Configuración

### Script de Verificación

```bash
#!/bin/bash

echo "🔍 Verificando configuración del proyecto..."
echo ""

# 1. Backend .env
if [ -f "backend/.env" ]; then
  echo "✅ backend/.env existe"
else
  echo "❌ backend/.env NO existe - ejecuta: cp backend/.env.example backend/.env"
fi

# 2. gcloud autenticado
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
  echo "✅ gcloud autenticado"
else
  echo "❌ gcloud NO autenticado - ejecuta: gcloud auth login"
fi

# 3. Proyecto configurado
PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -n "$PROJECT" ]; then
  echo "✅ Proyecto GCP configurado: $PROJECT"
else
  echo "❌ Proyecto GCP NO configurado - ejecuta: gcloud config set project <PROJECT_ID>"
fi

# 4. Billing vinculado
if gcloud billing projects describe $PROJECT &>/dev/null; then
  BILLING=$(gcloud billing projects describe $PROJECT --format="value(billingEnabled)")
  if [ "$BILLING" = "True" ]; then
    echo "✅ Billing habilitado"
  else
    echo "⚠️ Billing NO habilitado - vincular cuenta"
  fi
else
  echo "⚠️ No se puede verificar billing"
fi

# 5. Ansible instalado
if command -v ansible-playbook &>/dev/null; then
  echo "✅ Ansible instalado"
else
  echo "❌ Ansible NO instalado"
fi

# 6. kubectl instalado
if command -v kubectl &>/dev/null; then
  echo "✅ kubectl instalado"
else
  echo "❌ kubectl NO instalado"
fi

# 7. helm instalado
if command -v helm &>/dev/null; then
  echo "✅ helm instalado"
else
  echo "❌ helm NO instalado"
fi

# 8. docker running
if docker ps &>/dev/null; then
  echo "✅ Docker corriendo"
else
  echo "❌ Docker NO corriendo o sin permisos"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verificación completada. Corrige los ❌ antes de desplegar."
```

Guarda este script como `check-setup.sh` y ejecútalo:

```bash
chmod +x check-setup.sh
./check-setup.sh
```

---

## 📊 Estado del Repositorio Actual

### Archivos Modificados Pendientes de Commit

```bash
# Ver estado
git status --short
```

**Salida actual**:
```
 M frontend/nginx.conf                          # ← Cambio importante (nginx proxy)
 M frontend/src/App.js                          # ← Cambio importante (API_URL)
 M helm/todoapp/templates/postgres-deployment.yaml  # ← Fix PGDATA
 M .gitignore                                   # ← Actualizado
?? backend/.env.example                         # ← Nuevo (para copiar)
?? docs/                                        # ← Nueva documentación
?? SETUP-GUIDE.md                               # ← Guía de setup
?? POST-CLONE-CHECKLIST.md                      # ← Este archivo
```

### Archivos Críticos que Deben Commitearse

```bash
# Estos cambios son necesarios para que funcione en GCP
git add frontend/nginx.conf                    # Reverse proxy
git add frontend/src/App.js                    # API URL fix
git add helm/todoapp/templates/postgres-deployment.yaml  # PGDATA fix
git add .gitignore                             # Excluir .env
git add backend/.env.example                   # Template
git add docs/                                  # Documentación
git add SETUP-GUIDE.md                         # Guía completa
git add POST-CLONE-CHECKLIST.md                # Este checklist

# IMPORTANTE: Remover backend/.env del tracking
git rm --cached backend/.env

# Commit
git commit -m "feat: Add complete documentation and fix configuration

- Add nginx reverse proxy for backend API
- Fix frontend API URL for GCP deployment
- Fix PostgreSQL PGDATA configuration
- Update .gitignore to exclude backend/.env
- Add comprehensive documentation in docs/
- Add setup guide and post-clone checklist
- Remove backend/.env from git tracking"

# Push
git push
```

---

## 🎯 Resumen Ejecutivo

### Para el Mantenedor del Repositorio (Tú)

**Acción URGENTE antes de compartir el repo**:

```bash
# 1. Remover backend/.env del tracking
git rm --cached backend/.env

# 2. Agregar todos los cambios importantes
git add .

# 3. Commit y push
git commit -m "feat: Complete GCP deployment setup with documentation"
git push
```

### Para Nuevos Usuarios que Clonen

**Pasos en orden**:

1. ✅ Clonar repositorio
2. ✅ Copiar `backend/.env.example` → `backend/.env`
3. ✅ Autenticar con `gcloud auth login`
4. ✅ Editar `ansible/inventories/gcp/group_vars/all.yml` (project ID)
5. ✅ Vincular billing
6. ✅ Ejecutar `ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml`

**Documentación**:
- 📘 `SETUP-GUIDE.md` - Guía completa de configuración
- 📘 `docs/04-DEPLOYMENT-COMMANDS.md` - Comandos de despliegue
- 📘 `docs/05-MANUAL-AUTOSCALING-TEST.md` - Pruebas de autoscaling

---

## ✅ Confirmación Final

Una vez que hagas el commit que remueve `backend/.env` del tracking:

- ✅ El repositorio será **100% clonable** sin problemas
- ✅ No habrá archivos sensibles en git
- ✅ Nuevos usuarios solo necesitan:
  - Copiar `.env.example` → `.env`
  - Autenticar con GCP
  - Cambiar `gcp_project_id` en Ansible
  - Ejecutar `ansible-playbook`

**El proyecto estará production-ready para compartir**. 🎉
