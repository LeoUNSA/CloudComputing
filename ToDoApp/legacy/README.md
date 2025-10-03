# Legacy Files

Esta carpeta contiene archivos de la implementación anterior con Docker Compose.

## Archivos incluidos:

- `docker-compose.yml` - Configuración original de la aplicación con Docker Compose

## ¿Por qué conservar estos archivos?

1. **Referencia histórica** - Para recordar cómo estaba configurada la aplicación originalmente
2. **Desarrollo local alternativo** - Para desarrollo rápido sin Kubernetes
3. **Comparación** - Para verificar que la migración a Kubernetes mantiene toda la funcionalidad
4. **Documentación** - Como ejemplo de la arquitectura previa

## Migración completada

La aplicación ahora utiliza:
- ✅ **Kubernetes** con Kind para orquestación
- ✅ **Helm** para gestión de despliegues  
- ✅ **Prometheus** para monitoreo

## Uso actual

Para la aplicación actual, utiliza los comandos del directorio raíz:

```bash
# Despliegue completo
make full-deploy

# Ver estado
make status

# Acceder a la aplicación
# Frontend: http://localhost:30000
# Backend: http://localhost:30001
```

## Uso legacy (opcional)

Si necesitas usar la versión Docker Compose por alguna razón:

```bash
# Desde el directorio raíz
docker-compose -f legacy/docker-compose.yml up -d
```

> **Nota**: La versión de Kubernetes es la recomendada para uso en producción.