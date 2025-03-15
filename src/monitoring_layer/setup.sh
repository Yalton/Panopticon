#!/bin/bash
set -e
# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

clear
echo -e "\n${BOLD}${CYAN}╔═════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║      🚀 IoT Monitoring Project Setup        ║${NC}"
echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════╝${NC}\n"

# Check dependencies
echo -e "${BOLD}${BLUE}[1/5]${NC} ${BOLD}Checking dependencies...${NC}"

if ! command -v k3d &> /dev/null; then
  echo -e "  ${RED}✘ k3d not found${NC}"
  echo -e "    ${YELLOW}Install with:${NC} brew install k3d"
  exit 1
else
  echo -e "  ${GREEN}✓ k3d found${NC} $(k3d version | head -n1 | awk '{print $3}')"
fi

if ! command -v kubectl &> /dev/null; then
  echo -e "  ${RED}✘ kubectl not found${NC}"
  echo -e "    ${YELLOW}Install with:${NC} brew install kubectl"
  exit 1
else
  echo -e "  ${GREEN}✓ kubectl found${NC} $(kubectl version --client | grep -o "Client Version: v[0-9.]*" | awk '{print $3}')"
fi

echo -e "\n${BOLD}${BLUE}[2/5]${NC} ${BOLD}Setting up Kubernetes cluster...${NC}"

# Check if the cluster already exists
if k3d cluster list | grep -q "iot-cluster"; then
  echo -e "  ${YELLOW}ℹ Cluster 'iot-cluster' already exists${NC}"
  echo -ne "  ${CYAN}Do you want to delete and recreate it? (y/n):${NC} "
  read -r DELETE_CLUSTER
  if [[ $DELETE_CLUSTER =~ ^[Yy]$ ]]; then
    echo -ne "  ${YELLOW}⚠ Deleting existing cluster...${NC} "
    k3d cluster delete iot-cluster > /dev/null 2>&1
    echo -e "${GREEN}done${NC}"
  else
    echo -e "  ${GREEN}✓ Using existing cluster${NC}"
  fi
fi

# Create a new cluster if it doesn't exist or was deleted
if ! k3d cluster list | grep -q "iot-cluster"; then
  echo -e "  ${YELLOW}⚙ Creating K3s cluster with k3d...${NC}"
  echo -e "    ${CYAN}• 2 agent nodes${NC}"
  echo -e "    ${CYAN}• 1 server node${NC}"
  echo -e "    ${CYAN}• Port mapping: 8080:80${NC}"
  
  k3d cluster create iot-cluster \
    --agents 2 \
    --servers 1 \
    --port "8080:80@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" > /dev/null 2>&1
  
  echo -e "  ${GREEN}✓ K3s cluster created successfully!${NC}"
fi

echo -e "\n${BOLD}${BLUE}[3/5]${NC} ${BOLD}Configuring Kubernetes environment...${NC}"

# Set up the IoT monitoring namespace
echo -ne "  ${YELLOW}⚙ Creating 'iot-monitoring' namespace...${NC} "
kubectl create namespace iot-monitoring > /dev/null 2>&1 || echo -ne "${YELLOW}(already exists)${NC} "
echo -e "${GREEN}done${NC}"

# Set the namespace as default for the current context
echo -ne "  ${YELLOW}⚙ Setting 'iot-monitoring' as the default namespace...${NC} "
kubectl config set-context --current --namespace=iot-monitoring > /dev/null 2>&1
echo -e "${GREEN}done${NC}"

# Verify storage class exists
echo -ne "  ${YELLOW}⚙ Verifying storage class availability...${NC} "
if kubectl get storageclass | grep -q "local-path"; then
  echo -e "${GREEN}available${NC}"
else
  echo -e "${RED}not found${NC}"
  echo -e "  ${YELLOW}⚠ Warning: No default storage class found. This might cause issues for database persistence.${NC}"
fi

# Check cluster status
echo -e "  ${YELLOW}⚙ Verifying cluster nodes:${NC}"
kubectl get nodes | sed 's/^/    /'

echo -e "  ${GREEN}✓ Kubernetes environment configured${NC}"

echo -e "\n${BOLD}${BLUE}[4/5]${NC} ${BOLD}Deploying IoT monitoring components...${NC}"

# Deploy TimescaleDB
echo -ne "  ${YELLOW}⚙ Deploying TimescaleDB...${NC} "
kubectl apply -f timescaledb/ > /dev/null 2>&1
echo -e "${GREEN}done${NC}"

# Deploy PostGIS
echo -ne "  ${YELLOW}⚙ Deploying PostGIS...${NC} "
kubectl apply -f postgis/ > /dev/null 2>&1
echo -e "${GREEN}done${NC}"

# Build and load MQTT bridge image
echo -e "  ${YELLOW}⚙ Building MQTT bridge image...${NC}"
cd mqtt-bridge/src
docker build -t mqtt-bridge:latest . > /dev/null 2>&1
echo -ne "  ${YELLOW}⚙ Loading image into cluster...${NC} "
k3d image import mqtt-bridge:latest -c iot-cluster > /dev/null 2>&1
echo -e "${GREEN}done${NC}"
cd ../..

# Deploy MQTT bridge
echo -ne "  ${YELLOW}⚙ Deploying MQTT bridge...${NC} "
kubectl apply -f mqtt-bridge/ > /dev/null 2>&1
echo -e "${GREEN}done${NC}"

# Deploy Grafana
echo -ne "  ${YELLOW}⚙ Deploying Grafana...${NC} "
kubectl apply -f grafana/ > /dev/null 2>&1
echo -e "${GREEN}done${NC}"

# Wait for components to be ready
echo -e "  ${YELLOW}⚙ Waiting for components to start...${NC}"

echo -ne "    ${CYAN}• TimescaleDB...${NC} "
kubectl wait --namespace iot-monitoring --for=condition=ready pod --selector=app=timescaledb --timeout=60s > /dev/null 2>&1 && echo -e "${GREEN}ready${NC}" || echo -e "${YELLOW}pending${NC}"

echo -ne "    ${CYAN}• PostGIS...${NC} "
kubectl wait --namespace iot-monitoring --for=condition=ready pod --selector=app=postgis --timeout=60s > /dev/null 2>&1 && echo -e "${GREEN}ready${NC}" || echo -e "${YELLOW}pending${NC}"

echo -ne "    ${CYAN}• MQTT Bridge...${NC} "
kubectl wait --namespace iot-monitoring --for=condition=ready pod --selector=app=mqtt-bridge --timeout=60s > /dev/null 2>&1 && echo -e "${GREEN}ready${NC}" || echo -e "${YELLOW}pending${NC}"

echo -ne "    ${CYAN}• Grafana...${NC} "
kubectl wait --namespace iot-monitoring --for=condition=ready pod --selector=app=grafana --timeout=60s > /dev/null 2>&1 && echo -e "${GREEN}ready${NC}" || echo -e "${YELLOW}pending${NC}"

echo -e "\n${BOLD}${BLUE}[5/5]${NC} ${BOLD}Setup complete!${NC}"

# Show summary with animations
echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              🎉 IoT Platform Ready                    ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"

# Get statuses
TIMESCALE_STATUS=$(kubectl get pods -l app=timescaledb -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
POSTGIS_STATUS=$(kubectl get pods -l app=postgis -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
MQTT_STATUS=$(kubectl get pods -l app=mqtt-bridge -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
GRAFANA_STATUS=$(kubectl get pods -l app=grafana -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")

# Display component status
echo -e "\n${BOLD}System Status:${NC}"
if [[ "$TIMESCALE_STATUS" == "Running" ]]; then
  echo -e "  ${GREEN}✓${NC} ${BOLD}TimescaleDB${NC} - ${TIMESCALE_STATUS}"
else
  echo -e "  ${YELLOW}⚠${NC} ${BOLD}TimescaleDB${NC} - ${TIMESCALE_STATUS}"
fi

if [[ "$POSTGIS_STATUS" == "Running" ]]; then
  echo -e "  ${GREEN}✓${NC} ${BOLD}PostGIS${NC} - ${POSTGIS_STATUS}"
else
  echo -e "  ${YELLOW}⚠${NC} ${BOLD}PostGIS${NC} - ${POSTGIS_STATUS}"
fi

if [[ "$MQTT_STATUS" == "Running" ]]; then
  echo -e "  ${GREEN}✓${NC} ${BOLD}MQTT Bridge${NC} - ${MQTT_STATUS}"
else
  echo -e "  ${YELLOW}⚠${NC} ${BOLD}MQTT Bridge${NC} - ${MQTT_STATUS}"
fi

if [[ "$GRAFANA_STATUS" == "Running" ]]; then
  echo -e "  ${GREEN}✓${NC} ${BOLD}Grafana${NC} - ${GRAFANA_STATUS}"
else
  echo -e "  ${YELLOW}⚠${NC} ${BOLD}Grafana${NC} - ${GRAFANA_STATUS}"
fi

# Get service endpoints
echo -e "\n${BOLD}Service Endpoints:${NC}"
echo -e "  ${PURPLE}• ${BOLD}TimescaleDB:${NC} timescaledb:5432"
echo -e "  ${PURPLE}• ${BOLD}PostGIS:${NC} postgis:5432"
echo -e "  ${PURPLE}• ${BOLD}MQTT Broker:${NC} mqtt-bridge:8883"
echo -e "  ${PURPLE}• ${BOLD}Grafana:${NC} grafana:3000 (http://grafana.local)"

# Grafana access
echo -e "\n${BOLD}${CYAN}Grafana Dashboard${NC}"
echo -e "  ${YELLOW}• ${BOLD}Web Access:${NC}"
echo -e "    🔗 ${UNDERLINE}http://grafana.local${NC} (requires host entry)"
echo -e "    🔗 http://localhost:3000 (after running port-forward)"
echo -e "  ${YELLOW}• ${BOLD}Login Credentials:${NC}"
echo -e "    👤 Username: ${BOLD}admin${NC}"
echo -e "    🔑 Password: ${BOLD}admin${NC}"
echo -e "  ${YELLOW}• ${BOLD}Quick Access:${NC}"
echo -e "    ${CYAN}kubectl port-forward -n iot-monitoring svc/grafana 3000:3000 &${NC}"

# Preconfigured dashboards
echo -e "\n${BOLD}${GREEN}Preconfigured Dashboards:${NC}"
echo -e "  📊 ${BOLD}IoT Sensor Overview${NC} - Metrics from all sensors"
echo -e "  🗺️ ${BOLD}Spatial Data Monitor${NC} - Geographic visualization"
echo -e "  📈 ${BOLD}Time-Series Analysis${NC} - Historical trends"

echo -e "\n${BOLD}${BLUE}Getting Started:${NC}"
echo -e "  1️⃣  Connect your devices to the MQTT broker"
echo -e "  2️⃣  Run your data pipelines to process incoming data"
echo -e "  3️⃣  View real-time analytics in the Grafana dashboards"
echo -e "  4️⃣  Configure alerts for critical thresholds"

echo -e "\n${GREEN}${BOLD}Your IoT Monitoring Platform is ready for action!${NC}\n"