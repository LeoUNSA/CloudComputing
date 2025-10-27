#!/bin/bash

# Script de instalación de dependencias para Arch Linux
# Prepara el sistema para desplegar TodoApp en GCP con AutoScaling

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Setup de Dependencias - Arch Linux${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Actualizar sistema
echo -e "${GREEN}[1/8] Actualizando sistema...${NC}"
if command_exists yay; then
    yay -Syu --noconfirm
elif command_exists paru; then
    paru -Syu --noconfirm
else
    sudo pacman -Syu --noconfirm
fi
echo ""

# Instalar Python y pip (necesario para Ansible)
echo -e "${GREEN}[2/8] Instalando Python y pip...${NC}"
if ! command_exists python3; then
    sudo pacman -S --noconfirm python python-pip
else
    echo "Python ya está instalado: $(python3 --version)"
fi
echo ""

# Instalar Ansible
echo -e "${GREEN}[3/8] Instalando Ansible...${NC}"
if ! command_exists ansible; then
    sudo pacman -S --noconfirm ansible
else
    echo "Ansible ya está instalado: $(ansible --version | head -n1)"
fi
echo ""

# Instalar Google Cloud SDK
echo -e "${GREEN}[4/8] Instalando Google Cloud SDK...${NC}"
if ! command_exists gcloud; then
    if command_exists yay; then
        yay -S --noconfirm google-cloud-sdk
    elif command_exists paru; then
        paru -S --noconfirm google-cloud-sdk
    else
        echo -e "${YELLOW}Instalando desde AUR con makepkg...${NC}"
        cd /tmp
        git clone https://aur.archlinux.org/google-cloud-sdk.git
        cd google-cloud-sdk
        makepkg -si --noconfirm
        cd -
    fi
else
    echo "gcloud ya está instalado: $(gcloud --version | head -n1)"
fi
echo ""

# Instalar kubectl
echo -e "${GREEN}[5/8] Instalando kubectl...${NC}"
if ! command_exists kubectl; then
    sudo pacman -S --noconfirm kubectl
else
    echo "kubectl ya está instalado: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi
echo ""

# Instalar Helm
echo -e "${GREEN}[6/8] Instalando Helm...${NC}"
if ! command_exists helm; then
    sudo pacman -S --noconfirm helm
else
    echo "helm ya está instalado: $(helm version --short)"
fi
echo ""

# Instalar Docker
echo -e "${GREEN}[7/8] Instalando Docker...${NC}"
if ! command_exists docker; then
    sudo pacman -S --noconfirm docker
    
    # Habilitar y arrancar servicio Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Agregar usuario al grupo docker
    echo -e "${YELLOW}Agregando usuario $USER al grupo docker...${NC}"
    sudo usermod -aG docker $USER
    echo -e "${YELLOW}⚠️  Necesitas cerrar sesión y volver a entrar para que los cambios de grupo surtan efecto${NC}"
else
    echo "Docker ya está instalado: $(docker --version)"
fi
echo ""

# Instalar utilidades adicionales
echo -e "${GREEN}[8/8] Instalando utilidades adicionales...${NC}"
sudo pacman -S --noconfirm git wget curl base-devel jq make
echo ""

# Verificar instalaciones
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verificando Instalaciones${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_tool() {
    if command_exists "$1"; then
        echo -e "${GREEN}✓${NC} $1: $(command -v $1)"
    else
        echo -e "${RED}✗${NC} $1: No instalado"
    fi
}

check_tool python3
check_tool pip
check_tool ansible
check_tool gcloud
check_tool kubectl
check_tool helm
check_tool docker
check_tool git
check_tool make
check_tool jq

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Configuración Adicional${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Inicializar gcloud
echo -e "${YELLOW}Para configurar Google Cloud SDK, ejecuta:${NC}"
echo -e "  ${GREEN}gcloud init${NC}"
echo ""

# Información sobre Docker
if command_exists docker; then
    if groups $USER | grep -q docker; then
        echo -e "${GREEN}✓${NC} Usuario ya está en el grupo docker"
    else
        echo -e "${YELLOW}⚠️  Necesitas cerrar sesión y volver a entrar para usar docker sin sudo${NC}"
        echo -e "O ejecuta: ${GREEN}newgrp docker${NC}"
    fi
fi
echo ""

# Siguiente paso
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Instalación Completada!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo ""
echo -e "1. Reiniciar sesión (para aplicar grupo docker):"
echo -e "   ${GREEN}logout${NC} (y volver a entrar)"
echo -e "   O: ${GREEN}newgrp docker${NC}"
echo ""
echo -e "2. Configurar Google Cloud:"
echo -e "   ${GREEN}gcloud init${NC}"
echo ""
echo -e "3. Crear proyecto en GCP y service account:"
echo -e "   Ver: ${GREEN}README-GCP-AUTOSCALING.md${NC} (Sección 'Requisitos Previos')"
echo ""
echo -e "4. Configurar variables de entorno:"
echo -e "   ${GREEN}export GCP_PROJECT_ID=\"tu-proyecto-id\"${NC}"
echo -e "   ${GREEN}export GCP_CREDENTIALS_FILE=\"\$HOME/.gcp/credentials.json\"${NC}"
echo ""
echo -e "5. Ejecutar validación:"
echo -e "   ${GREEN}cd ansible && ./validate-setup.sh${NC}"
echo ""
echo -e "6. Desplegar:"
echo -e "   ${GREEN}make -f Makefile.gcp deploy${NC}"
echo ""
