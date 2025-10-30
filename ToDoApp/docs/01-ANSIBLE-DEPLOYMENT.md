# Uso de Ansible para Despliegue en GCP

## Índice
1. [Introducción](#introducción)
2. [Estructura de Ansible](#estructura-de-ansible)
3. [Inventarios y Variables](#inventarios-y-variables)
4. [Playbooks Principales](#playbooks-principales)
5. [Tareas Detalladas](#tareas-detalladas)
6. [Flujo de Ejecución](#flujo-de-ejecución)
7. [Ventajas del Enfoque](#ventajas-del-enfoque)

---

## Introducción

Este proyecto utiliza **Ansible** como única herramienta de Infrastructure as Code (IaC) para automatizar completamente el despliegue de una aplicación web en Google Cloud Platform (GCP) con Kubernetes.

### ¿Por qué Ansible?

- **Agentless**: No requiere instalar agentes en los servidores
- **Idempotente**: Puede ejecutarse múltiples veces con el mismo resultado
- **Declarativo**: Describe el estado deseado, no los pasos exactos
- **Multiplataforma**: Funciona con GCP, AWS, Azure, bare metal, etc.

---

## Estructura de Ansible

```
ansible/
├── ansible.cfg                          # Configuración de Ansible
├── inventories/
│   └── gcp/
│       ├── hosts.yml                    # Inventario (localhost)
│       └── group_vars/
│           └── all.yml                  # Variables globales del proyecto
├── tasks/                               # Directorio de tareas modulares
│   ├── setup-gke-cluster.yml           # Tareas: crear cluster GKE
│   ├── build-and-push-images.yml       # Tareas: build/push Docker
│   └── deploy-app.yml                  # Tareas: deploy con Helm
├── main.yml                             # Playbook orquestador principal
├── cleanup.yml                          # Playbook de limpieza
└── README.md                            # Documentación
```

---

## Inventarios y Variables

### Inventario (`inventories/gcp/hosts.yml`)

```yaml
all:
  hosts:
    127.0.0.1:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
```

**Explicación**: 
- Ejecuta todo en `localhost` (la máquina del desarrollador)
- Usa conexión local (no SSH)
- Especifica Python 3 como intérprete

### Variables Globales (`inventories/gcp/group_vars/all.yml`)

```yaml
# GCP Project Configuration
gcp_project_id: "todoapp-autoscaling-demo"
gcp_region: "us-central1"
gcp_zone: "us-central1-a"
gcp_credentials_file: ""  # Vacío = usar credenciales de usuario

# GKE Cluster Configuration
gke_cluster_name: "todoapp-autoscaling-cluster"
gke_cluster_version: "latest"
gke_network_name: "todoapp-network"
gke_subnet_name: "todoapp-subnet"

# Node Pool Configuration for Autoscaling
gke_node_pool:
  initial_node_count: 2
  min_node_count: 2      # Mínimo de nodos
  max_node_count: 10     # Máximo de nodos (Cluster Autoscaler)
  machine_type: "e2-standard-2"
  disk_size_gb: 50

# Autoscaling Configuration (HPA)
autoscaling:
  backend:
    min_replicas: 2
    max_replicas: 10
    target_cpu_utilization: 50
    target_memory_utilization: 70
  frontend:
    min_replicas: 2
    max_replicas: 8
    target_cpu_utilization: 60
    target_memory_utilization: 75
```

**Variables Clave**:
- `gke_node_pool.min/max_node_count`: Control del Cluster Autoscaler
- `autoscaling.backend/frontend`: Configuración de HPA por componente
- `docker_registry`: `gcr.io/{project_id}` para Google Container Registry

---

## Playbooks Principales

### 1. Playbook Orquestador (`main.yml`)

```yaml
---
- name: Complete GKE AutoScaling Deployment Pipeline
  hosts: localhost
  gather_facts: yes
  
  tasks:
    - name: Step 1 - Setup GKE Cluster
      include_tasks: tasks/setup-gke-cluster.yml
      tags: [cluster, setup]
      
    - name: Step 2 - Build and Push Docker Images
      include_tasks: tasks/build-and-push-images.yml
      tags: [build, images]
      
    - name: Step 3 - Deploy Application
      include_tasks: tasks/deploy-app.yml
      tags: [deploy, app]
```

**Características**:
- **Modular**: Divide el deployment en 3 fases claras
- **Tags**: Permite ejecutar solo partes específicas
- **Secuencial**: Cada paso depende del anterior

**Ejecución**:
```bash
# Despliegue completo
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml

# Solo crear cluster
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml --tags cluster

# Solo deploy app (cluster ya existe)
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml --tags deploy
```

### 2. Playbook de Limpieza (`cleanup.yml`)

```yaml
---
- name: Cleanup GKE Resources
  hosts: localhost
  gather_facts: no
  
  tasks:
    - name: Confirm cleanup
      pause:
        prompt: "¿Eliminar cluster GKE? (yes/no)"
      register: confirm
      
    - name: Delete Helm release
      command: helm uninstall todoapp -n todoapp
      when: confirm.user_input == "yes"
      
    - name: Delete GKE cluster
      command: >
        gcloud container clusters delete {{ gke_cluster_name }}
        --zone={{ gcp_zone }}
        --quiet
      when: confirm.user_input == "yes"
```

---

## Tareas Detalladas

### Tarea 1: Setup GKE Cluster (`tasks/setup-gke-cluster.yml`)

**Responsabilidades**:
1. Validar credenciales GCP
2. Habilitar APIs necesarias (Compute, Container, Registry)
3. Crear red VPC y subnet
4. Crear cluster GKE con autoscaling habilitado
5. Obtener credenciales para kubectl
6. Crear namespace de la aplicación

**Fragmento clave**:

```yaml
- name: Create GKE cluster with autoscaling
  command: >
    gcloud container clusters create {{ gke_cluster_name }}
    --zone={{ gcp_zone }}
    --network={{ gke_network_name }}
    --subnetwork={{ gke_subnet_name }}
    --machine-type={{ gke_node_pool.machine_type }}
    --num-nodes={{ gke_node_pool.initial_node_count }}
    --min-nodes={{ gke_node_pool.min_node_count }}
    --max-nodes={{ gke_node_pool.max_node_count }}
    --enable-autoscaling                    # ← Cluster Autoscaler
    --enable-autorepair
    --enable-autoupgrade
    --addons=HorizontalPodAutoscaling       # ← HPA addon
```

**Detalles importantes**:
- `--enable-autoscaling`: Activa Cluster Autoscaler (escalado de nodos)
- `--min-nodes/--max-nodes`: Define rango de nodos
- `--addons=HorizontalPodAutoscaling`: Habilita HPA en el cluster
- `failed_when` con `'already exists'`: Hace la tarea idempotente

### Tarea 2: Build and Push Images (`tasks/build-and-push-images.yml`)

**Responsabilidades**:
1. Configurar Docker para usar GCR
2. Construir imágenes backend y frontend
3. Subir imágenes a Google Container Registry

**Fragmento clave**:

```yaml
- name: Configure Docker to use gcloud as credential helper
  command: gcloud auth configure-docker --quiet
  changed_when: false

- name: Build backend Docker image
  command: >
    docker build 
    -t {{ backend_image }}
    -f backend/Dockerfile
    backend/
  args:
    chdir: "{{ playbook_dir }}/.."
  register: backend_build
  changed_when: true

- name: Push backend image to GCR
  command: docker push {{ backend_image }}
  changed_when: true
```

**Variables dinámicas**:
```yaml
backend_image: "gcr.io/{{ gcp_project_id }}/todoapp-backend:{{ image_tag }}"
frontend_image: "gcr.io/{{ gcp_project_id }}/todoapp-frontend:{{ image_tag }}"
```

### Tarea 3: Deploy Application (`tasks/deploy-app.yml`)

**Responsabilidades**:
1. Instalar metrics-server (si no existe)
2. Generar archivo de values para Helm
3. Desplegar aplicación con Helm
4. Esperar a que los deployments estén listos
5. Obtener IP del LoadBalancer

**Generación dinámica de values**:

```yaml
- name: Create values override file for GCP deployment
  copy:
    dest: /tmp/values-gcp-autoscaling.yaml
    content: |
      image:
        backend:
          repository: {{ docker_registry }}/todoapp-backend
          tag: "{{ image_tag }}"
        frontend:
          repository: {{ docker_registry }}/todoapp-frontend
          tag: "{{ image_tag }}"
      
      autoscaling:
        enabled: true
        backend:
          minReplicas: {{ autoscaling.backend.min_replicas }}
          maxReplicas: {{ autoscaling.backend.max_replicas }}
          targetCPUUtilizationPercentage: {{ autoscaling.backend.target_cpu_utilization }}
```

**Deploy con Helm**:

```yaml
- name: Deploy TodoApp using Helm
  command: >
    helm upgrade --install {{ helm_release_name }}
    {{ helm_chart_path }}
    --namespace {{ app_namespace }}
    --values /tmp/values-gcp-autoscaling.yaml
    --wait
    --timeout 10m
```

---

## Flujo de Ejecución

### Diagrama de Flujo

```
┌─────────────────────────────────────────────────────────────┐
│  1. INICIO: ansible-playbook main.yml                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  2. SETUP GKE CLUSTER (tasks/setup-gke-cluster.yml)         │
├─────────────────────────────────────────────────────────────┤
│  ✓ Validar credenciales GCP                                 │
│  ✓ Habilitar APIs (compute, container, registry)            │
│  ✓ Crear VPC network                                        │
│  ✓ Crear subnet                                             │
│  ✓ Crear cluster GKE con autoscaling                        │
│  ✓ Obtener kubeconfig                                       │
│  ✓ Crear namespace 'todoapp'                                │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  3. BUILD & PUSH IMAGES (tasks/build-and-push-images.yml)   │
├─────────────────────────────────────────────────────────────┤
│  ✓ Configurar Docker para GCR                               │
│  ✓ Build imagen backend                                     │
│  ✓ Build imagen frontend                                    │
│  ✓ Push backend a GCR                                       │
│  ✓ Push frontend a GCR                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  4. DEPLOY APP (tasks/deploy-app.yml)                       │
├─────────────────────────────────────────────────────────────┤
│  ✓ Agregar repo Helm metrics-server                         │
│  ✓ Instalar metrics-server en kube-system                   │
│  ✓ Generar values-gcp-autoscaling.yaml                      │
│  ✓ Helm upgrade --install todoapp                           │
│  ✓ Esperar deployments ready                                │
│  ✓ Obtener LoadBalancer IP                                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  5. FIN: Aplicación desplegada y accesible                  │
│     - Frontend: http://<LB-IP>:3000                         │
│     - HPA configurado (2-10 pods backend, 2-8 frontend)     │
│     - Cluster Autoscaler activo (2-10 nodos)                │
└─────────────────────────────────────────────────────────────┘
```

### Tiempo Estimado por Fase

| Fase | Tiempo | Descripción |
|------|--------|-------------|
| Setup GKE Cluster | 5-8 min | Crear cluster y nodos |
| Build & Push Images | 2-3 min | Compilar frontend React |
| Deploy App | 3-5 min | Helm install + esperar pods |
| **Total** | **10-16 min** | Deployment completo |

---

## Ventajas del Enfoque

### 1. **Idempotencia**

Todas las tareas están diseñadas para ser idempotentes:

```yaml
- name: Create VPC network
  command: >
    gcloud compute networks create {{ gke_network_name }}
    ...
  register: network_result
  failed_when: 
    - network_result.rc != 0
    - "'already exists' not in network_result.stderr"
  changed_when: network_result.rc == 0
```

**Resultado**: Puedes ejecutar el playbook múltiples veces sin errores.

### 2. **Configuración como Código**

Todas las configuraciones están en `group_vars/all.yml`:
- Cambiar región: modificar `gcp_region`
- Ajustar autoscaling: modificar `autoscaling.backend.max_replicas`
- Cambiar tipo de máquina: modificar `gke_node_pool.machine_type`

### 3. **Modularidad con Tags**

```bash
# Solo reconstruir y redesplegar imágenes
ansible-playbook main.yml --tags build,deploy

# Solo actualizar la aplicación (sin tocar cluster)
ansible-playbook main.yml --tags deploy
```

### 4. **Separación de Responsabilidades**

- **Ansible**: Infraestructura (cluster, nodos, networking)
- **Helm**: Aplicación (pods, services, HPAs)
- **Docker**: Empaquetado de aplicaciones

### 5. **Trazabilidad**

Cada tarea tiene `register` y `changed_when`:
```yaml
- name: Build backend Docker image
  command: docker build ...
  register: backend_build
  changed_when: true
```

Ansible reporta exactamente qué cambió en cada ejecución.

---

## Mejores Prácticas Implementadas

### 1. **Variables Parametrizadas**

Evitar hardcodear valores:
```yaml
# ❌ Mal
command: gcloud container clusters create my-cluster --zone=us-central1-a

# ✅ Bien
command: >
  gcloud container clusters create {{ gke_cluster_name }}
  --zone={{ gcp_zone }}
```

### 2. **Manejo de Errores**

```yaml
failed_when: 
  - command_result.rc != 0
  - "'already exists' not in command_result.stderr"
```

Permite que recursos existentes no fallen el playbook.

### 3. **Timeouts y Retries**

```yaml
- name: Wait for cluster to be ready
  command: kubectl cluster-info
  register: cluster_info
  until: cluster_info.rc == 0
  retries: 10
  delay: 10
```

### 4. **Uso de `changed_when`**

```yaml
- name: Get cluster credentials
  command: gcloud container clusters get-credentials ...
  changed_when: false  # No marca como "changed"
```

Comandos informativos no deben marcar cambios.

---

## Comandos de Referencia

### Ejecutar Deployment Completo
```bash
cd /home/leo/CloudComputing/ToDoApp
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml
```

### Verificar Sintaxis (Dry-run)
```bash
ansible-playbook ansible/main.yml --syntax-check
ansible-playbook ansible/main.yml --check  # Dry-run (no ejecuta)
```

### Ver Variables Disponibles
```bash
ansible-inventory -i ansible/inventories/gcp/hosts.yml --list --yaml
```

### Ejecutar con Verbosidad
```bash
ansible-playbook ansible/main.yml -vvv  # Modo debug
```

### Limpiar Recursos
```bash
ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/cleanup.yml
```

---

## Conclusión

Este enfoque de Ansible proporciona:
- ✅ **Automatización completa**: Un comando despliega todo
- ✅ **Reproducibilidad**: Mismo resultado en cada ejecución
- ✅ **Flexibilidad**: Fácil adaptar a otros proveedores cloud
- ✅ **Mantenibilidad**: Código claro y bien estructurado
- ✅ **Control de versiones**: Todo el IaC en Git

El uso de Ansible como única herramienta IaC simplifica la arquitectura y reduce la curva de aprendizaje al evitar múltiples herramientas (Terraform, CloudFormation, etc.).
