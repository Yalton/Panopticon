#!/bin/bash
# This script tests the MQTT Bridge connection to TimescaleDB
# Ensure proper cleanup on script exit
cleanup() {
  echo -e "${YELLOW}Cleaning up port forwarding...${NC}"
  if [ ! -z "$PF_PID" ]; then
    kill $PF_PID 2>/dev/null || true
  fi
  # Extra safety - kill any kubectl port-forward processes
  pkill -f "kubectl port-forward.*timescaledb" 2>/dev/null || true
  # Remove temporary SQL file if it exists
  if [ ! -z "$TMP_SQL" ] && [ -f "$TMP_SQL" ]; then
    rm "$TMP_SQL" 2>/dev/null || true
  fi
}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Set up cleanup on script exit
trap cleanup EXIT

echo -e "${PURPLE}Testing MQTT Bridge Connection and Functionality...${NC}"

# Function to run SQL with clear section headers
# Disable pager with PAGER=/bin/cat and set expanded output off
run_query() {
  local title="$1"
  local query="$2"
  echo ""
  echo -e "${YELLOW}===== $title =====${NC}"
  PGPASSWORD=timescaledbpassword PAGER=/bin/cat psql -h localhost -p 5432 -U postgres -d sensor_data -X -c "$query" || {
    echo -e "${RED}Query failed: $title${NC}"
    # Don't exit on query failure, continue with other tests
  }
  echo ""
}

# Check if the MQTT bridge pod is running
echo -e "${YELLOW}Checking MQTT bridge pod status...${NC}"
POD_STATUS=$(kubectl get pods -l app=mqtt-bridge -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

if [ "$POD_STATUS" != "Running" ]; then
  echo -e "${RED}MQTT bridge pod is not running. Current status: $POD_STATUS${NC}"
  echo -e "${YELLOW}Checking pod details:${NC}"
  kubectl describe pod -l app=mqtt-bridge
  echo -e "${RED}MQTT bridge is not properly deployed. Please check your deployment.${NC}"
  echo -e "${YELLOW}Continuing tests to verify database connectivity...${NC}"
else
  echo -e "${GREEN}MQTT bridge pod is running.${NC}"
  
  # View the logs to check for activity
  echo -e "${YELLOW}Checking MQTT bridge logs for activity (last 10 lines)...${NC}"
  kubectl logs -l app=mqtt-bridge --tail=10
fi

# Forward the PostgreSQL port to localhost
echo -e "${YELLOW}Setting up port forwarding to TimescaleDB...${NC}"
kubectl port-forward -n iot-monitoring svc/timescaledb 5432:5432 &
PF_PID=$!

# Wait for port forwarding to be established
echo -e "${YELLOW}Waiting for port forwarding to be ready...${NC}"
sleep 3

# Verify port forwarding is working
timeout 5 bash -c 'until nc -z localhost 5432; do sleep 0.5; done' || {
  echo -e "${RED}Error: Port forwarding to TimescaleDB failed!${NC}"
  exit 1
}

echo -e "${GREEN}TimescaleDB connection established.${NC}"

# Check TimescaleDB version and extensions
run_query "TimescaleDB Version" "SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';"

# Check if sensor_data table exists
run_query "Verify Sensor Data Table" "
SELECT 
  table_schema, 
  table_name 
FROM 
  information_schema.tables 
WHERE 
  table_name = 'sensor_data';
"

# Check if we have recent data
run_query "Recent Data (Last Hour)" "
SELECT 
  time, 
  device_id, 
  sensor_type, 
  value, 
  location_id 
FROM 
  sensor_data 
WHERE 
  time > NOW() - INTERVAL '1 hour'
ORDER BY 
  time DESC
LIMIT 10;
"

# Check data counts by sensor
run_query "Data Count by Sensor Type (Last Hour)" "
SELECT 
  device_id,
  sensor_type, 
  COUNT(*) as record_count 
FROM 
  sensor_data 
WHERE 
  time > NOW() - INTERVAL '1 hour'
GROUP BY 
  device_id, sensor_type
ORDER BY 
  device_id, sensor_type;
"

# Check if development mode sensors are present
run_query "Development Mode Sensors Data Check" "
SELECT 
  device_id, 
  COUNT(*) as record_count,
  MIN(time) as first_record,
  MAX(time) as last_record,
  NOW() - MAX(time) as time_since_last_record
FROM 
  sensor_data
WHERE 
  device_id IN ('sensor001', 'sensor002')
GROUP BY 
  device_id;
"

# Insert test data to verify db write access
run_query "Insert Test Data" "
INSERT INTO sensor_data (time, device_id, sensor_type, value, location_id) 
VALUES 
  (NOW(), 'test-script', 'temperature', 22.5, 'test-location'),
  (NOW(), 'test-script', 'humidity', 45.0, 'test-location'),
  (NOW(), 'test-script', 'pressure', 1013.2, 'test-location');
"

# Verify test data insertion
run_query "Verify Test Data Insertion" "
SELECT 
  time, 
  device_id, 
  sensor_type, 
  value, 
  location_id
FROM 
  sensor_data 
WHERE 
  device_id = 'test-script'
ORDER BY 
  time DESC
LIMIT 5;
"

# Run time-series analysis query
run_query "Time-Series Analysis Demo" "
SELECT
  device_id,
  sensor_type,
  time_bucket('15 minutes', time) AS bucket,
  AVG(value) as avg_value,
  MIN(value) as min_value,
  MAX(value) as max_value,
  COUNT(*) as reading_count
FROM
  sensor_data
WHERE
  time > NOW() - INTERVAL '3 hours'
  AND device_id IN ('sensor001', 'sensor002', 'test-script')
GROUP BY
  bucket, device_id, sensor_type
ORDER BY
  device_id, sensor_type, bucket DESC
LIMIT 20;
"

echo -e "${GREEN}All MQTT bridge tests completed.${NC}"
# Cleanup happens automatically thanks to the trap