# 🚀 Despliegue en Google Cloud Platform (GCP)

## ⚡ Nuevo: AutoScaling Completo en GCP

TodoApp ahora soporta despliegue completo en **Google Kubernetes Engine (GKE)** con **AutoScaling** tanto a nivel de **pods** (HPA) como de **nodos** (Cluster Autoscaler), usando **Ansible** como herramienta de Infrastructure as Code.

### 📋 Características GCP

- ✅ **GKE Cluster** con Cluster Autoscaler (2-10 nodos)
- ✅ **HPA** para backend y frontend con métricas de CPU y Memoria
- ✅ **Google Container Registry** para imágenes Docker
- ✅ **Cloud Load Balancer** para acceso externo
- ✅ **Provisión automatizada** con Ansible
- ✅ **Scripts de prueba de carga** incluidos
- ✅ **Monitoreo en tiempo real** de escalado

### 🎯 Configuración de AutoScaling

| Componente | Min → Max | Métricas |
|------------|-----------|----------|
| **Backend Pods** | 2 → 10 | CPU: 50%, Mem: 70% |
| **Frontend Pods** | 2 → 8 | CPU: 60%, Mem: 75% |
| **Cluster Nodes** | 2 → 10 | Automático (GKE) |

### 📚 Documentación GCP

Para desplegar en GCP, consulta la documentación específica:

- **[📖 README-GCP-AUTOSCALING.md](README-GCP-AUTOSCALING.md)** - Guía completa de AutoScaling en GCP
- **[⚡ QUICKSTART-GCP.md](QUICKSTART-GCP.md)** - Inicio rápido (5 minutos)
- **[📝 CHEATSHEET.md](CHEATSHEET.md)** - Referencia rápida de comandos
- **[🎨 DIAGRAMS.md](DIAGRAMS.md)** - Diagramas visuales de autoscaling
- **[📋 IMPLEMENTATION-SUMMARY.md](IMPLEMENTATION-SUMMARY.md)** - Resumen de implementación

### 🚀 Quick Start GCP

```bash
# 1. Configurar variables de entorno
export GCP_PROJECT_ID="tu-proyecto-id"
export GCP_CREDENTIALS_FILE="$HOME/.gcp/credentials.json"

# 2. Validar configuración
cd ansible
./validate-setup.sh

# 3. Desplegar todo
ansible-playbook main.yml

# 4. Probar autoscaling
cd ../load-testing
./monitor-autoscaling.sh  # En terminal 1
./simple-load-test.sh     # En terminal 2

# 5. Limpiar recursos
cd ../ansible
ansible-playbook cleanup.yml
```

### 🔧 O usar Makefile

```bash
make -f Makefile.gcp help      # Ver comandos disponibles
make -f Makefile.gcp validate  # Validar setup
make -f Makefile.gcp deploy    # Desplegar todo
make -f Makefile.gcp monitor   # Monitorear
make -f Makefile.gcp load-test # Generar carga
make -f Makefile.gcp destroy   # Limpiar
```

### 💰 Costos Estimados

- **Configuración base** (2 nodos): ~$0.35/hora (~$8/día)
- **Escalado máximo** (10 nodos): ~$1.75/hora (~$42/día)
- **Prueba de 1 hora**: $0.35 - $2.00 USD

⚠️ **Importante**: No olvides ejecutar `make destroy` al terminar para evitar cargos.

### 📦 Estructura de Archivos GCP

```
ansible/                           # Infraestructura como Código
├── main.yml                      # Playbook principal
├── setup-gke-cluster.yml         # Crear cluster GKE
├── build-and-push-images.yml     # Build y push a GCR
├── deploy-app.yml                # Deploy con Helm + HPA
└── cleanup.yml                   # Eliminar recursos

load-testing/                     # Pruebas de carga
├── monitor-autoscaling.sh        # Monitor en tiempo real
├── simple-load-test.sh           # Test básico
├── run-load-test.sh              # Test avanzado
└── extreme-load-test.sh          # Test extremo (⚠️ alto costo)

helm/todoapp/templates/
└── hpa.yaml                      # HorizontalPodAutoscaler (nuevo)
```

### 🎓 Conceptos Demostrados

1. **Infrastructure as Code** con Ansible (no Terraform)
2. **Horizontal Pod Autoscaler** (HPA) con métricas múltiples
3. **Cluster Autoscaler** para escalado de nodos
4. **Políticas de escalado** optimizadas
5. **Cloud Native** en GCP con GKE
6. **Observabilidad** con Metrics Server

---

**Para despliegue local con Kind**, consulta la documentación original más abajo.

**Para despliegue en GCP con AutoScaling**, ve a [README-GCP-AUTOSCALING.md](README-GCP-AUTOSCALING.md).

---
