# 🚀 Setup Completo del Proyecto - Guía de Clonación

## ⚠️ Información Importante para Nuevos Usuarios

Este documento explica **todo lo necesario** para clonar y ejecutar el proyecto en un equipo nuevo.

---

## 📋 Pre-requisitos

### Software Necesario

```bash
# En Arch Linux
sudo pacman -S google-cloud-sdk kubectl helm docker ansible git

# En Ubuntu/Debian
sudo apt update
sudo apt install -y git ansible docker.io
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt update && sudo apt install google-cloud-sdk kubectl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Cuenta de GCP

✅ **Cuenta de Google Cloud Platform** con:
- Billing account activa
- Permisos para crear proyectos
- Acceso a Compute Engine API
- Acceso a Kubernetes Engine API

---

## 📥 Paso 1: Clonar el Repositorio

```bash
# Clonar el proyecto
git clone <URL_DEL_REPOSITORIO>
cd ToDoApp
```

---

## 🔐 Paso 2: Configuración de Credenciales GCP

### Opción A: Autenticación de Usuario (Recomendado para Desarrollo)

```bash
# Iniciar sesión en GCP
gcloud auth login

# Configurar proyecto (cambia por tu project ID)
gcloud config set project todoapp-autoscaling-demo

# Configurar región y zona
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Configurar Docker para GCR
gcloud auth configure-docker

# Obtener credenciales de aplicación por defecto
gcloud auth application-default login
```

**✅ Esta opción NO requiere archivos de credenciales** - usa tu sesión de gcloud

### Opción B: Service Account (Recomendado para CI/CD)

```bash
# Crear service account
export GCP_PROJECT_ID="tu-proyecto-id"

gcloud iam service-accounts create todoapp-deployer \
  --display-name="TodoApp Deployer"

# Asignar roles necesarios
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Crear y descargar key
mkdir -p ~/.gcp
gcloud iam service-accounts keys create ~/.gcp/credentials.json \
  --iam-account=todoapp-deployer@${GCP_PROJECT_ID}.iam.gserviceaccount.com

# Configurar variable de entorno
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.gcp/credentials.json"
```

⚠️ **Importante**: El archivo `~/.gcp/credentials.json` está en `.gitignore` y NO se sube al repositorio

---

## 🔧 Paso 3: Configurar Variables del Proyecto

### Método 1: Variables de Entorno (Opcional)

```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar .env con tus valores
nano .env

# Cargar variables
source .env
```

### Método 2: Editar Ansible Directamente (Más Simple)

```bash
# Editar archivo de variables de Ansible
nano ansible/inventories/gcp/group_vars/all.yml
```

**Cambiar los siguientes valores**:

```yaml
# Línea 3: Cambiar project ID (OBLIGATORIO)
gcp_project_id: "TU-PROJECT-ID-AQUI"

# Líneas 4-5: Cambiar región/zona si deseas (OPCIONAL)
gcp_region: "us-central1"
gcp_zone: "us-central1-a"

# Línea 6: Dejar vacío si usas autenticación de usuario
gcp_credentials_file: ""

# Resto de configuraciones: OK con valores por defecto
```

---

## 🚀 Paso 4: Vincular Billing Account

```bash
# Listar billing accounts disponibles
gcloud billing accounts list

# Vincular billing al proyecto
gcloud billing projects link <TU_PROJECT_ID> \
  --billing-account=<TU_BILLING_ACCOUNT_ID>

# Verificar
gcloud billing projects describe <TU_PROJECT_ID>
```

---

## 🎯 Paso 5: Desplegar la Aplicación

### Despliegue Completo con Ansible

```bash
# Desde el directorio raíz del proyecto
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml
```

**⏱️ Tiempo estimado**: 10-16 minutos

**Qué hace este comando**:
1. ✅ Crea VPC network y subnet
2. ✅ Crea cluster GKE con autoscaling
3. ✅ Construye imágenes Docker (backend y frontend)
4. ✅ Sube imágenes a GCR
5. ✅ Despliega aplicación con Helm
6. ✅ Configura HPA y Cluster Autoscaler

### Verificar Despliegue

```bash
# Ver nodos del cluster
kubectl get nodes

# Ver pods
kubectl get pods -n todoapp

# Ver HPA
kubectl get hpa -n todoapp

# Ver services (esperar a que frontend tenga EXTERNAL-IP)
kubectl get svc -n todoapp
```

### Obtener URL de la Aplicación

```bash
# Obtener IP externa
EXTERNAL_IP=$(kubectl get svc todoapp-frontend -n todoapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "🌐 Aplicación disponible en: http://$EXTERNAL_IP:3000"
```

---

## 🧪 Paso 6: Probar Autoscaling (Opcional)

Ver documentación detallada en: `docs/05-MANUAL-AUTOSCALING-TEST.md`

**Comando rápido**:

```bash
# Generar carga (5 generadores)
for i in {1..5}; do 
  kubectl run load-gen-$i --image=busybox --restart=Never -n todoapp -- \
    /bin/sh -c "while true; do wget -q -O- http://todoapp-backend:5000/stress?duration=40000; done"
done

# Monitorear en otra terminal
watch kubectl get hpa -n todoapp
```

---

## 🗑️ Limpieza de Recursos

```bash
# Opción 1: Con Ansible
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml

# Opción 2: Manual
gcloud container clusters delete todoapp-autoscaling-cluster --zone=us-central1-a --quiet
```

---

## 📁 Archivos que NO están en Git (Por Seguridad)

Los siguientes archivos están en `.gitignore` y **NO se suben al repositorio**:

```
.env                           # Variables de entorno locales
~/.gcp/credentials.json        # Credenciales de service account
node_modules/                  # Dependencias de Node.js
build/                         # Build de frontend
.vscode/                       # Configuración de VS Code
*.log                          # Logs
```

### ¿Qué Hacer Si Clonas el Proyecto?

1. ✅ **Crear tu propio `.env`** copiando `.env.example`
2. ✅ **Autenticarte con `gcloud auth login`** (si usas autenticación de usuario)
3. ✅ **O crear tu propio service account** (si usas service account)
4. ✅ **Editar `ansible/inventories/gcp/group_vars/all.yml`** con tu project ID

---

## 🆘 Problemas Comunes

### Error: "The user does not have access to service account"

**Causa**: No tienes permisos en el proyecto GCP

**Solución**:
```bash
# Verificar que eres owner o editor del proyecto
gcloud projects get-iam-policy <TU_PROJECT_ID>

# Añadir rol si es necesario (requiere admin)
gcloud projects add-iam-policy-binding <TU_PROJECT_ID> \
  --member="user:tu-email@gmail.com" \
  --role="roles/owner"
```

### Error: "Billing account for project not found"

**Causa**: Proyecto no tiene billing vinculado

**Solución**: Ver Paso 4 arriba

### Error: "gcloud command hangs"

**Causa**: gcloud intenta verificar actualizaciones

**Solución**:
```bash
gcloud config set component_manager/disable_update_check true
gcloud config set disable_usage_reporting true
```

### Error: "Cannot pull image from GCR"

**Causa**: Docker no autenticado con GCR

**Solución**:
```bash
gcloud auth configure-docker
```

### Error: "metrics not available" en HPA

**Causa**: metrics-server no instalado

**Solución**:
```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}
```

---

## 📚 Documentación Adicional

### Documentación Completa en `docs/`:

1. `01-ANSIBLE-DEPLOYMENT.md` - Cómo funciona Ansible
2. `02-AUTOSCALING-MECHANISMS.md` - HPA y Cluster Autoscaler
3. `03-CLOUD-ARCHITECTURE.md` - Arquitectura cloud
4. `04-DEPLOYMENT-COMMANDS.md` - Comandos de despliegue
5. `05-MANUAL-AUTOSCALING-TEST.md` - Pruebas de autoscaling
6. `06-LOAD-GENERATION-INTERNALS.md` - Generación de tráfico

### READMEs en Raíz:

- `README.md` - Documentación general del proyecto
- `README-GCP-AUTOSCALING.md` - Autoscaling en GCP
- `QUICKSTART-GCP.md` - Guía rápida
- `CHEATSHEET.md` - Comandos útiles

---

## ✅ Checklist de Configuración Exitosa

Antes de desplegar, verifica:

- [ ] gcloud CLI instalado y autenticado
- [ ] kubectl instalado
- [ ] helm instalado
- [ ] docker instalado y corriendo
- [ ] ansible instalado
- [ ] Proyecto GCP creado
- [ ] Billing account vinculado
- [ ] `gcp_project_id` editado en `ansible/inventories/gcp/group_vars/all.yml`
- [ ] APIs habilitadas (se hace automáticamente por Ansible)

---

## 🎓 Arquitectura del Proyecto

```
ToDoApp/
├── ansible/                    # Infraestructura como código
│   ├── main.yml               # Playbook principal
│   ├── cleanup.yml            # Playbook de limpieza
│   ├── inventories/gcp/
│   │   └── group_vars/all.yml # ← EDITAR AQUÍ: gcp_project_id
│   └── tasks/                 # Tareas modulares
├── backend/                   # Backend Node.js/Express
│   ├── server.js              # Endpoint /stress para load testing
│   └── Dockerfile
├── frontend/                  # Frontend React
│   ├── nginx.conf             # Reverse proxy para /api
│   └── Dockerfile
├── helm/todoapp/              # Helm chart
│   ├── values.yaml            # Configuración de autoscaling
│   └── templates/
│       ├── hpa.yaml           # HPA para backend/frontend
│       └── ...
├── docs/                      # Documentación detallada
├── load-testing/              # Scripts de pruebas de carga
├── .env.example               # Plantilla de variables (copiar a .env)
├── .gitignore                 # Archivos excluidos de git
└── README.md                  # Este archivo
```

---

## 🔒 Seguridad

### Información Sensible NUNCA en Git

- ❌ Credenciales de service account (`.json`)
- ❌ Archivos `.env` con secrets
- ❌ API keys o tokens
- ❌ Contraseñas de bases de datos (excepto demos)

### Cómo Manejamos Secretos

1. **Credenciales GCP**: Usa `gcloud auth login` (sesión local) o crea tu propio service account
2. **Variables de proyecto**: Edita `ansible/inventories/gcp/group_vars/all.yml` (no contiene secretos)
3. **Secretos de K8s**: Se crean dinámicamente en el cluster (no en git)

---

## 📞 Soporte

Si tienes problemas:

1. ✅ Revisa `docs/04-DEPLOYMENT-COMMANDS.md` sección Troubleshooting
2. ✅ Verifica logs: `kubectl logs -n todoapp <pod-name>`
3. ✅ Revisa eventos: `kubectl get events -n todoapp --sort-by='.lastTimestamp'`

---

## 🎯 Resumen Rápido

```bash
# 1. Clonar
git clone <repo>
cd ToDoApp

# 2. Autenticar
gcloud auth login
gcloud config set project <TU_PROJECT_ID>

# 3. Editar configuración
nano ansible/inventories/gcp/group_vars/all.yml
# Cambiar: gcp_project_id: "TU_PROJECT_ID"

# 4. Vincular billing
gcloud billing projects link <TU_PROJECT_ID> --billing-account=<BILLING_ID>

# 5. Desplegar
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml

# 6. Acceder
kubectl get svc todoapp-frontend -n todoapp
# Abrir http://<EXTERNAL-IP>:3000
```

**¡Listo! 🎉**
