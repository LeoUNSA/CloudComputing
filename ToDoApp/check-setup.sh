#!/bin/bash

echo "🔍 Verificando configuración del proyecto ToDoApp..."
echo ""

ERRORS=0
WARNINGS=0

# 1. Backend .env
if [ -f "backend/.env" ]; then
  echo "✅ backend/.env existe"
else
  echo "❌ backend/.env NO existe - ejecuta: cp backend/.env.example backend/.env"
  ((ERRORS++))
fi

# 2. gcloud autenticado
if gcloud auth list --filter=status:ACTIVE --format="value(account)" &>/dev/null; then
  ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
  echo "✅ gcloud autenticado como: $ACCOUNT"
else
  echo "❌ gcloud NO autenticado - ejecuta: gcloud auth login"
  ((ERRORS++))
fi

# 3. Proyecto configurado
PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ -n "$PROJECT" ]; then
  echo "✅ Proyecto GCP configurado: $PROJECT"
  
  # 4. Billing vinculado
  if gcloud billing projects describe $PROJECT --format="value(billingEnabled)" 2>/dev/null | grep -q "True"; then
    echo "✅ Billing habilitado en proyecto $PROJECT"
  else
    echo "⚠️  Billing NO habilitado - ejecuta:"
    echo "   gcloud billing projects link $PROJECT --billing-account=<BILLING_ID>"
    ((WARNINGS++))
  fi
else
  echo "❌ Proyecto GCP NO configurado - ejecuta: gcloud config set project <PROJECT_ID>"
  ((ERRORS++))
fi

# 5. Verificar project ID en Ansible
ANSIBLE_PROJECT=$(grep "gcp_project_id:" ansible/inventories/gcp/group_vars/all.yml 2>/dev/null | grep -v "lookup" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -n "$ANSIBLE_PROJECT" ]; then
  if [ "$ANSIBLE_PROJECT" = "todoapp-autoscaling-demo" ]; then
    echo "⚠️  Project ID en Ansible es el default: $ANSIBLE_PROJECT"
    echo "   Edita: ansible/inventories/gcp/group_vars/all.yml"
    ((WARNINGS++))
  else
    echo "✅ Project ID en Ansible configurado: $ANSIBLE_PROJECT"
  fi
else
  echo "⚠️  No se pudo leer project ID de Ansible"
  ((WARNINGS++))
fi

# 6. Ansible instalado
if command -v ansible-playbook &>/dev/null; then
  VERSION=$(ansible-playbook --version | head -1)
  echo "✅ Ansible instalado: $VERSION"
else
  echo "❌ Ansible NO instalado - instalar según SETUP-GUIDE.md"
  ((ERRORS++))
fi

# 7. kubectl instalado
if command -v kubectl &>/dev/null; then
  VERSION=$(kubectl version --client --short 2>/dev/null | head -1)
  echo "✅ kubectl instalado: $VERSION"
else
  echo "❌ kubectl NO instalado - instalar según SETUP-GUIDE.md"
  ((ERRORS++))
fi

# 8. helm instalado
if command -v helm &>/dev/null; then
  VERSION=$(helm version --short 2>/dev/null)
  echo "✅ helm instalado: $VERSION"
else
  echo "❌ helm NO instalado - instalar según SETUP-GUIDE.md"
  ((ERRORS++))
fi

# 9. docker running
if docker ps &>/dev/null; then
  echo "✅ Docker corriendo"
else
  echo "❌ Docker NO corriendo o sin permisos"
  echo "   Ejecuta: sudo systemctl start docker"
  echo "   O añade usuario a grupo: sudo usermod -aG docker \$USER"
  ((ERRORS++))
fi

# 10. Docker autenticado con GCR
if grep -q "gcr.io" ~/.docker/config.json 2>/dev/null; then
  echo "✅ Docker configurado para GCR"
else
  echo "⚠️  Docker NO configurado para GCR - ejecuta: gcloud auth configure-docker"
  ((WARNINGS++))
fi

# 11. Verificar archivos críticos
echo ""
echo "📁 Verificando archivos del proyecto..."

CRITICAL_FILES=(
  "ansible/main.yml"
  "ansible/cleanup.yml"
  "helm/todoapp/Chart.yaml"
  "backend/Dockerfile"
  "frontend/Dockerfile"
  "frontend/nginx.conf"
)

for file in "${CRITICAL_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $file"
  else
    echo "  ❌ $file NO encontrado"
    ((ERRORS++))
  fi
done

# Resumen
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo "🎉 TODO OK - Puedes desplegar con:"
  echo "   ansible-playbook -i ansible/inventories/gcp/hosts.yml ansible/main.yml"
elif [ $ERRORS -eq 0 ]; then
  echo "⚠️  $WARNINGS advertencia(s) - Revisa antes de desplegar"
  echo "   Puedes continuar, pero se recomienda corregir las advertencias"
else
  echo "❌ $ERRORS error(es) encontrado(s) - Corrige antes de desplegar"
  echo "   Revisa SETUP-GUIDE.md para instrucciones"
fi

echo ""
exit $ERRORS
