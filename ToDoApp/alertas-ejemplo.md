# 🚨 EJEMPLOS DE ALERTAS PARA TODOAPP

## ⚡ ALERTAS CRÍTICAS
- 🔴 **Pod Down**: Si algún pod de TodoApp no está corriendo
- 🔴 **Database Unavailable**: Si PostgreSQL no responde
- 🔴 **High Memory Usage**: Si memoria > 90%
- 🔴 **API Response Time**: Si latencia > 5 segundos

## ⚠️ ALERTAS DE WARNING
- 🟡 **High CPU Usage**: Si CPU > 80% por 5 minutos
- 🟡 **Low Disk Space**: Si espacio < 20%
- 🟡 **Too Many Restarts**: Si pods reinician > 3 veces/hora
- 🟡 **API Error Rate**: Si errores 5xx > 5%

## 📊 ALERTAS DE NEGOCIO
- 🔵 **No New Tasks**: Si no se crean tareas en 1 hora
- 🔵 **Low User Activity**: Si requests < 10/minuto
- 🔵 **Database Growing Fast**: Si DB crece > 100MB/día

## 📧 CANALES DE NOTIFICACIÓN
- Email
- Slack
- Discord
- Webhook HTTP
- PagerDuty