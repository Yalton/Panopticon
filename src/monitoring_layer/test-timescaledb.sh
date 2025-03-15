#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing TimescaleDB Connection and Functionality...${NC}"

# Set up port forwarding in the background
echo -e "${YELLOW}Setting up port forwarding to TimescaleDB...${NC}"
kubectl port-forward svc/timescaledb 5432:5432 &
PF_PID=$!

# Give port forwarding a moment to establish
sleep 3

# Create a temporary SQL file
TMP_SQL=$(mktemp)

cat > "$TMP_SQL" << EOF
-- Verify TimescaleDB extension
SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';

-- Verify hypertable exists
SELECT * FROM timescaledb_information.hypertables WHERE hypertable_name = 'sensor_data';

-- Insert some test data
INSERT INTO sensor_data (time, device_id, sensor_type, value, location_id)
VALUES
  (NOW(), 'rpi-001', 'temperature', 22.5, 'living-room'),
  (NOW(), 'rpi-001', 'humidity', 45.2, 'living-room'),
  (NOW(), 'rpi-002', 'temperature', 19.8, 'bedroom'),
  (NOW() - INTERVAL '1 hour', 'rpi-001', 'temperature', 23.1, 'living-room');

-- Query the data
SELECT * FROM sensor_data ORDER BY time DESC;

-- Run a time-series query (last hour)
SELECT 
  device_id,
  sensor_type,
  AVG(value) as avg_value,
  MIN(value) as min_value,
  MAX(value) as max_value
FROM sensor_data
WHERE time > NOW() - INTERVAL '1 day'
GROUP BY device_id, sensor_type
ORDER BY device_id, sensor_type;
EOF

# Run the SQL commands
echo -e "${YELLOW}Executing SQL commands to test TimescaleDB...${NC}"
PGPASSWORD=timescaledbpassword psql -h localhost -U postgres -d sensor_data -f "$TMP_SQL"

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
kill $PF_PID
rm "$TMP_SQL"

echo -e "${GREEN}TimescaleDB test completed!${NC}"
