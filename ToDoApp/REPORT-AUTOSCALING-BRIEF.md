# Informe breve — AutoScaling TodoApp en GCP

## Descripción de la aplicación
TodoApp es una aplicación de gestión de tareas (frontend React + backend Node.js + PostgreSQL) empaquetada en contenedores Docker y preparada para su despliegue en Kubernetes. Proporciona endpoints REST para crear/leer/actualizar/eliminar tareas y una interfaz web servida por Nginx.

## Proveedor de la nube
Se utiliza Google Cloud Platform (GCP). El despliegue objetivo es Google Kubernetes Engine (GKE). Las imágenes pueden almacenarse en Google Container Registry (GCR) y el balanceo es gestionado por Cloud Load Balancer.

## Infraestructura como Código (IaC)
- Herramienta: Ansible (única IaC; no se usa Terraform).
- Estructura: playbooks en `ansible/`:
  - `setup-gke-cluster.yml`: crea el cluster GKE, VPC/subnet y habilita autoscaling de nodos.
  - `build-and-push-images.yml`: construye y sube imágenes a GCR.
  - `deploy-app.yml`: despliega la aplicación con Helm y configura componentes necesarios (metrics-server, namespace, valores personalizados).
  - `cleanup.yml`: elimina recursos del proyecto cuando termine la demo.
- Variables y entornos: `ansible/inventories/gcp/group_vars/all.yml` contiene configuración del proyecto, parámetros del node pool y límites de autoscaling (min/max nodos, recursos, thresholds).
- Beneficios: reproducibilidad, idempotencia, y facilidad para automatizar build/deploy/teardown desde la terminal.

## Cómo se maneja el Autoescalado
- Autoescalado de pods (HPA):
  - Implementado mediante manifestos Helm (plantilla `helm/todoapp/templates/hpa.yaml`).
  - HPA configura objetivos por componente (backend y frontend) con métricas de CPU y memoria (ej. backend: target CPU 50%, memoria 70%).
  - Políticas: scale-up agresivo (respuesta rápida), scale-down conservador (ventana de estabilización de 5 minutos) para evitar oscilaciones.
  - Requisito: `metrics-server` instalado para exponer métricas al HPA.

- Autoescalado de nodos (Cluster Autoscaler):
  - Habilitado en el node pool de GKE (min/max nodes configurables, p. ej. 2–10).
  - Cuando el scheduler deja pods en estado `Pending` por falta de recursos, el Cluster Autoscaler solicita nodos adicionales a GCP.
  - Cuando los nodos quedan subutilizados durante el período definido, se drenan y eliminan con seguridad.

- Prueba y validación: se incluye un endpoint `/stress` en el backend para generar carga CPU y varios scripts en `load-testing/` para simular escenarios (monitor, carga simple, carga extrema que puede disparar escalado de nodos).

## Otros detalles importantes
- Observabilidad: `metrics-server` + `kubectl top` permiten ver métricas; Prometheus/Grafana pueden añadirse para dashboards más completos.
- Seguridad: las credenciales del service account se gestionan como JSON local (`~/.gcp/credentials.json`) y Ansible usa esas credenciales para ejecutar `gcloud`/kubectl en la pipeline.
- Costos y limpieza: el playbook `cleanup.yml` y el Makefile (`Makefile.gcp`) ofrecen comandos para destruir recursos; es crítico ejecutar la limpieza después de las pruebas para evitar cargos en GCP.
- Requisitos locales (ejemplos para Arch Linux): `gcloud`, `kubectl`, `helm`, `ansible`, `docker` y utilidades (`git`, `make`) — hay un script `setup-arch-linux.sh` que automatiza la instalación.

## Conclusión (resumen en 3 líneas)
TodoApp está preparado para demostraciones de AutoScaling en GKE usando Ansible como IaC. El autoscaling se gestiona combinando HPA (pods) y Cluster Autoscaler (nodos), con métricas expuestas por `metrics-server`. El repositorio incluye automatización completa y scripts de prueba para validar comportamiento bajo carga y limpiar recursos.

---

Si quieres, puedo:
- añadir este informe al README principal, o
- generar una versión en PDF para compartir, o
- ejecutar el despliegue ahora (si confirmas que quieres proceder y que `~/.gcp/credentials.json` está presente).
