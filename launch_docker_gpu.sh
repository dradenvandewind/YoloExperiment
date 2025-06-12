#!/bin/bash

# Script de lancement Docker CUDA + GStreamer
# Usage: ./launch_docker.sh

set -e

echo "=== Configuration Docker CUDA + GStreamer ==="

# Vérifier si nvidia-smi fonctionne
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA drivers non détectés. Installer d'abord les drivers NVIDIA."
    exit 1
fi

echo "✅ NVIDIA drivers détectés:"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé."
    exit 1
fi

# Vérifier nvidia-container-toolkit
if ! docker run --rm --gpus all nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA Container Toolkit non configuré."
    echo "Installer avec:"
    echo "sudo apt-get install -y nvidia-container-toolkit"
    echo "sudo systemctl restart docker"
    exit 1
fi

echo "✅ NVIDIA Container Toolkit configuré"

# Autoriser X11 (pour l'affichage)
xhost +local:docker

# Variables
IMAGE_NAME="yolovo8gst:latest"
#"cuda-gstreamer:latest"
CONTAINER_NAME="cuda-gstreamer-dev"

# Construire l'image si elle n'existe pas
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "🔨 Construction de l'image Docker..."
    docker build -t $IMAGE_NAME .
fi

# Arrêter le container s'il existe déjà
if docker ps -a --format 'table {{.Names}}' | grep -q $CONTAINER_NAME; then
    echo "🛑 Arrêt du container existant..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

echo "🚀 Lancement du container..."

# Lancer le container
docker run -it --rm \
    --name $CONTAINER_NAME \
    --gpus all \
    --device /dev/dri:/dev/dri \
    --group-add video \
    --group-add render \
    --group-add audio \
    -e DISPLAY=$DISPLAY \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev/dri:/dev/dri \
    -v $(pwd):/workspace \
    --workdir /workspace \
    --privileged \
    $IMAGE_NAME \
    bash -c "
        echo '=== Container CUDA + GStreamer démarré ==='
        echo 'Utilisateur: $(whoami)'
        echo 'Répertoire: $(pwd)'
        echo ''
        echo 'Tests disponibles:'
        echo '  ~/test_setup.sh          # Test CUDA + GStreamer'
        echo '  nvidia-smi               # Statut GPU'
        echo '  gst-inspect-1.0          # Plugins GStreamer'
        echo ''
        exec bash
    "

# Nettoyer X11
xhost -local:docker

echo "✨ Container fermé"
