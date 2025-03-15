#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting IoT Monitoring Project K3s Setup${NC}"

# Check if k3d is installed
if ! command -v k3d &> /dev/null; then
    echo -e "${RED}k3d is not installed. Please install it first.${NC}"
    echo "You can use: brew install k3d"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install it first.${NC}"
    echo "You can use: brew install kubectl"
    exit 1
fi

# Check if the cluster already exists
if k3d cluster list | grep -q "iot-cluster"; then
    echo -e "${YELLOW}Cluster 'iot-cluster' already exists. Do you want to delete it and create a new one? (y/n)${NC}"
    read -r DELETE_CLUSTER
    
    if [[ $DELETE_CLUSTER =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        k3d cluster delete iot-cluster
    else
        echo -e "${YELLOW}Using existing cluster.${NC}"
    fi
fi

# Create a new cluster if it doesn't exist or was deleted
if ! k3d cluster list | grep -q "iot-cluster"; then
    echo -e "${YELLOW}Creating K3s cluster with k3d...${NC}"
    k3d cluster create iot-cluster \
        --agents 2 \
        --servers 1 \
        --port "8080:80@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0" # We'll install our own ingress if needed
    
    echo -e "${GREEN}K3s cluster created successfully!${NC}"
fi

# Set up the IoT monitoring namespace
echo -e "${YELLOW}Creating 'iot-monitoring' namespace...${NC}"
kubectl create namespace iot-monitoring 2>/dev/null || echo -e "${YELLOW}Namespace 'iot-monitoring' already exists.${NC}"

# Set the namespace as default for the current context
echo -e "${YELLOW}Setting 'iot-monitoring' as the default namespace...${NC}"
kubectl config set-context --current --namespace=iot-monitoring

# Verify storage class exists
echo -e "${YELLOW}Verifying storage class availability...${NC}"
if kubectl get storageclass | grep -q "local-path"; then
    echo -e "${GREEN}Default storage class 'local-path' is available.${NC}"
else
    echo -e "${YELLOW}No default storage class found. This might cause issues for database persistence.${NC}"
fi

# Check cluster status
echo -e "${YELLOW}Verifying cluster status:${NC}"
kubectl get nodes

echo -e "${GREEN}K3s setup complete! Your Kubernetes cluster is ready for the IoT Monitoring project.${NC}"

echo -e "${YELLOW}Starting timescaledb"
kubectl apply -f timescaledb/

echo -e "${YELLOW}Starting postgis"
kubectl apply -f postgis/