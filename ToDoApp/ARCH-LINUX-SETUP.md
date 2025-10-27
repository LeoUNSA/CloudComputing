# 🐧 Guía de Despliegue en Arch Linux - TodoApp GCP

## 📋 Índice
- [Instalación Automática](#instalación-automática)
- [Instalación Manual](#instalación-manual)
- [Configuración de GCP](#configuración-de-gcp)
- [Despliegue](#despliegue)
- [Troubleshooting](#troubleshooting)

---

## ⚡ Instalación Automática (Recomendado)

### Opción 1: Script Automatizado

```bash
# Ejecutar script de instalación
./setup-arch-linux.sh

# El script instala:
# - Python 3 y pip
# - Ansible
# - Google Cloud SDK
# - kubectl
# - Helm
# - Docker
# - Utilidades (git, wget, curl, make, jq)
```

### Después del script

1. **Reiniciar sesión** (para aplicar grupo docker):
   ```bash
   logout
   # Volver a entrar
   ```
   
   O usar `newgrp`:
   ```bash
   newgrp docker
   ```

2. **Inicializar gcloud**:
   ```bash
   gcloud init
   ```

---

## 🔧 Instalación Manual

Si prefieres instalar manualmente cada componente:

### 1. Actualizar sistema

```bash
sudo pacman -Syu
```

### 2. Instalar Python y Ansible

```bash
# Python (normalmente ya viene instalado en Arch)
sudo pacman -S python python-pip

# Ansible
sudo pacman -S ansible

# Verificar
python3 --version
ansible --version
```

### 3. Instalar Google Cloud SDK

**Opción A: Desde AUR (con yay/paru)**

```bash
# Si tienes yay
yay -S google-cloud-sdk

# O si tienes paru
paru -S google-cloud-sdk
```

**Opción B: Desde AUR (manual con makepkg)**

```bash
cd /tmp
git clone https://aur.archlinux.org/google-cloud-sdk.git
cd google-cloud-sdk
makepkg -si
```

**Opción C: Script de instalación oficial**

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Verificar:**
```bash
gcloud --version
```

### 4. Instalar kubectl

```bash
sudo pacman -S kubectl

# Verificar
kubectl version --client
```

### 5. Instalar Helm

```bash
sudo pacman -S helm

# Verificar
helm version
```

### 6. Instalar Docker

```bash
# Instalar Docker
sudo pacman -S docker

# Habilitar servicio
sudo systemctl enable docker
sudo systemctl start docker

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Aplicar cambios (elegir UNA opción)
# Opción 1: Cerrar sesión y volver a entrar
logout

# Opción 2: Nuevo grupo sin cerrar sesión
newgrp docker

# Verificar
docker --version
docker ps  # No debería pedir sudo
```

### 7. Instalar utilidades adicionales

```bash
sudo pacman -S git wget curl base-devel jq make
```

---

## 🔐 Configuración de GCP

### 1. Crear cuenta y proyecto en GCP

1. **Crear cuenta en GCP**:
   - Visita: https://console.cloud.google.com
   - Crea una cuenta (incluye $300 de crédito gratis)

2. **Crear proyecto**:
   ```bash
   # En la consola de GCP o usando gcloud
   export PROJECT_ID="todoapp-autoscaling-$(date +%s)"
   gcloud projects create $PROJECT_ID
   gcloud config set project $PROJECT_ID
   ```

3. **Habilitar facturación**:
   - Ve a: https://console.cloud.google.com/billing
   - Vincula el proyecto con una cuenta de facturación

### 2. Inicializar gcloud

```bash
gcloud init

# Selecciona:
# - Tu cuenta de Google
# - El proyecto creado
# - Región por defecto: us-central1
```

### 3. Crear Service Account

```bash
# Variables
export PROJECT_ID="tu-proyecto-id"  # Cambiar por tu ID
export SA_NAME="todoapp-deployer"

# Crear service account
gcloud iam service-accounts create $SA_NAME \
    --display-name="TodoApp Deployer" \
    --project=$PROJECT_ID

# Asignar roles necesarios
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Crear y descargar key
mkdir -p ~/.gcp
gcloud iam service-accounts keys create ~/.gcp/credentials.json \
    --iam-account=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --project=$PROJECT_ID

# Verificar
ls -lh ~/.gcp/credentials.json
```

### 4. Configurar variables de entorno

```bash
# Configurar variables
export GCP_PROJECT_ID="tu-proyecto-id"  # Cambiar por tu ID
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"

# Guardar en ~/.bashrc o ~/.zshrc para persistencia
echo "export GCP_PROJECT_ID=\"$GCP_PROJECT_ID\"" >> ~/.bashrc
echo "export GCP_CREDENTIALS_FILE=\"$HOME/.gcp/credentials.json\"" >> ~/.bashrc

# O si usas zsh
echo "export GCP_PROJECT_ID=\"$GCP_PROJECT_ID\"" >> ~/.zshrc
echo "export GCP_CREDENTIALS_FILE=\"$HOME/.gcp/credentials.json\"" >> ~/.zshrc

# Recargar
source ~/.bashrc  # o source ~/.zshrc
```

### 5. Autenticar gcloud con service account

```bash
gcloud auth activate-service-account \
    --key-file=$GCP_CREDENTIALS_FILE

gcloud config set project $GCP_PROJECT_ID
```

---

## 🚀 Despliegue

### 1. Validar setup

```bash
cd /home/leo/CloudComputing/ToDoApp/ansible
./validate-setup.sh
```

Esto verifica:
- ✅ Herramientas instaladas
- ✅ Variables de entorno configuradas
- ✅ Credenciales válidas
- ✅ Proyecto GCP configurado

### 2. Desplegar con Make (Recomendado)

```bash
cd /home/leo/CloudComputing/ToDoApp

# Ver comandos disponibles
make -f Makefile.gcp help

# Validar
make -f Makefile.gcp validate

# Desplegar todo (~20 minutos)
make -f Makefile.gcp deploy

# En otra terminal: Monitorear
make -f Makefile.gcp monitor

# Generar carga para probar autoscaling
make -f Makefile.gcp load-test

# Ver URL de acceso
make -f Makefile.gcp get-url

# Limpiar todo
make -f Makefile.gcp destroy
```

### 3. Desplegar con Ansible Directamente

```bash
cd /home/leo/CloudComputing/ToDoApp/ansible

# Deployment completo
ansible-playbook main.yml

# O por etapas:
ansible-playbook setup-gke-cluster.yml      # Solo cluster
ansible-playbook build-and-push-images.yml  # Solo imágenes
ansible-playbook deploy-app.yml             # Solo app

# Limpiar
ansible-playbook cleanup.yml
```

### 4. Probar AutoScaling

```bash
cd /home/leo/CloudComputing/ToDoApp/load-testing

# Terminal 1: Monitor en tiempo real
./monitor-autoscaling.sh

# Terminal 2: Generar carga
./simple-load-test.sh

# Para carga más intensa
CONCURRENT_WORKERS=30 DURATION=600 ./simple-load-test.sh

# Detener carga
make -f ../Makefile.gcp stop-load
```

---

## 🔍 Comandos Útiles

### Verificar instalaciones

```bash
# Versiones de herramientas
python3 --version
ansible --version
gcloud --version
kubectl version --client
helm version
docker --version

# Estado de Docker
systemctl status docker
docker ps
```

### Verificar GCP

```bash
# Proyecto actual
gcloud config get-value project

# Listar clusters
gcloud container clusters list --project=$GCP_PROJECT_ID

# Credenciales
gcloud auth list
```

### Verificar Kubernetes

```bash
# Info del cluster
kubectl cluster-info

# Nodos
kubectl get nodes

# Pods
kubectl get pods -n todoapp

# HPAs
kubectl get hpa -n todoapp
```

---

## 🐛 Troubleshooting

### Problema: "docker: permission denied"

**Causa**: Usuario no está en grupo docker

**Solución**:
```bash
# Verificar grupos
groups

# Si no está 'docker', agregar
sudo usermod -aG docker $USER

# Aplicar cambios
newgrp docker

# O cerrar sesión y volver a entrar
logout
```

### Problema: "gcloud: command not found" (después de instalar)

**Causa**: PATH no actualizado

**Solución**:
```bash
# Si instalaste con el script oficial
source ~/google-cloud-sdk/path.bash.inc
source ~/google-cloud-sdk/completion.bash.inc

# Agregar a ~/.bashrc
echo 'source ~/google-cloud-sdk/path.bash.inc' >> ~/.bashrc
echo 'source ~/google-cloud-sdk/completion.bash.inc' >> ~/.bashrc
```

### Problema: "Failed to connect to the GCE Metadata Server"

**Causa**: No estás en una VM de GCP (esto es normal en local)

**Solución**:
```bash
# Autenticar con service account
gcloud auth activate-service-account \
    --key-file=$GCP_CREDENTIALS_FILE
```

### Problema: Ansible no encuentra módulos de GCP

**Causa**: Falta librería de Python

**Solución**:
```bash
# Instalar dependencias de Ansible para GCP
pip install --user google-auth requests
```

### Problema: "ERROR: (gcloud.container.clusters.create) PERMISSION_DENIED"

**Causa**: Service account sin permisos o APIs no habilitadas

**Solución**:
```bash
# Habilitar APIs manualmente
gcloud services enable compute.googleapis.com --project=$GCP_PROJECT_ID
gcloud services enable container.googleapis.com --project=$GCP_PROJECT_ID
gcloud services enable containerregistry.googleapis.com --project=$GCP_PROJECT_ID

# Verificar roles del service account
gcloud projects get-iam-policy $GCP_PROJECT_ID
```

### Problema: Docker daemon no arranca

**Solución**:
```bash
# Ver logs
sudo journalctl -u docker.service

# Reiniciar servicio
sudo systemctl restart docker

# Verificar status
sudo systemctl status docker
```

### Problema: "No module named 'ansible'"

**Solución**:
```bash
# Reinstalar Ansible
sudo pacman -S ansible

# O con pip
pip install --user ansible
```

---

## 📊 Flujo Completo de Trabajo

```bash
# 1. INSTALACIÓN (una sola vez)
./setup-arch-linux.sh
logout  # y volver a entrar

# 2. CONFIGURACIÓN GCP (una sola vez)
gcloud init
# Crear proyecto y service account (ver arriba)
export GCP_PROJECT_ID="tu-proyecto-id"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"

# 3. VALIDACIÓN
cd ansible
./validate-setup.sh

# 4. DESPLIEGUE
make -f ../Makefile.gcp deploy

# 5. PRUEBAS (en otra terminal)
make -f ../Makefile.gcp monitor    # Terminal 1
make -f ../Makefile.gcp load-test  # Terminal 2

# 6. ACCESO
make -f ../Makefile.gcp get-url

# 7. LIMPIEZA
make -f ../Makefile.gcp destroy
```

---

## 💡 Tips para Arch Linux

### Usar AUR helper (yay)

```bash
# Instalar yay (si no lo tienes)
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Usar yay para instalar paquetes AUR
yay -S google-cloud-sdk
```

### Mantener sistema actualizado

```bash
# Actualizar todo
sudo pacman -Syu

# Con yay (incluye AUR)
yay -Syu
```

### Verificar servicios

```bash
# Ver servicios activos
systemctl list-units --type=service --state=running

# Docker
systemctl status docker

# Habilitar Docker en boot
sudo systemctl enable docker
```

---

## 📚 Recursos Adicionales

### Documentación de Arch Linux

- **Ansible**: https://wiki.archlinux.org/title/Ansible
- **Docker**: https://wiki.archlinux.org/title/Docker
- **AUR**: https://wiki.archlinux.org/title/Arch_User_Repository

### Documentación del Proyecto

- **README-GCP-AUTOSCALING.md** - Guía completa
- **QUICKSTART-GCP.md** - Inicio rápido
- **CHEATSHEET.md** - Comandos útiles

---

## ✅ Checklist de Instalación

- [ ] Sistema actualizado (`sudo pacman -Syu`)
- [ ] Python 3 instalado
- [ ] Ansible instalado
- [ ] Google Cloud SDK instalado
- [ ] kubectl instalado
- [ ] Helm instalado
- [ ] Docker instalado y corriendo
- [ ] Usuario en grupo docker
- [ ] gcloud inicializado
- [ ] Proyecto GCP creado
- [ ] Service account creado
- [ ] Credenciales descargadas
- [ ] Variables de entorno configuradas
- [ ] Validación exitosa (`./validate-setup.sh`)

---

**¡Todo listo para desplegar desde la terminal en Arch Linux!** 🚀
