#!/bin/bash

# Docker launch script CUDA + GStreamer
# Usage: ./launch_docker.sh

set -e

echo "=== Docker CUDA + GStreamer configuration ==="

# Vérifier si nvidia-smi fonctionne
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA drivers not detected. Install NVIDIA drivers first.."
    exit 1
fi

echo "✅ Detected NVIDIA drivers:"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé."
    exit 1
fi

# Vérifier nvidia-container-toolkit
if ! docker run --rm --gpus all nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA Container Toolkit not configured."
    echo "Install with:"
    echo "sudo apt-get install -y nvidia-container-toolkit"
    echo "sudo systemctl restart docker"
    exit 1
fi

echo "✅ NVIDIA Container Toolkit configured"

# Enable X11 (for display)
xhost +local:docker

# Variables
IMAGE_NAME="yolovo8gst:latest"
#"cuda-gstreamer:latest"
CONTAINER_NAME="cuda-gstreamer-dev"

#Build the image if it doesn't exist
if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" == "" ]]; then
    echo "🔨 Building the Docker image..."
    docker build -t $IMAGE_NAME .
fi

# Stop the container if it already exists
if docker ps -a --format 'table {{.Names}}' | grep -q $CONTAINER_NAME; then
    echo "🛑 Stopping the existing container..."
    docker stop $CONTAINER_NAME 2>/dev/null || true
    docker rm $CONTAINER_NAME 2>/dev/null || true
fi

echo "🚀 Container launch..."

# Launch the container

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

# Clean X11
xhost -local:docker

echo "✨ Closed container"
