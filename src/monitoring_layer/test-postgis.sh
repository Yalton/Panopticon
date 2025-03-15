#!/bin/bash
# This script tests the PostGIS installation and functionality

# Ensure any existing port-forwarding is cleaned up on script exit
cleanup() {
  echo "Cleaning up port forwarding..."
  if [ ! -z "$PF_PID" ]; then
    kill $PF_PID 2>/dev/null || true
  fi
  
  # Extra safety - kill any kubectl port-forward processes
  pkill -f "kubectl port-forward.*postgis" 2>/dev/null || true
}

# Set up cleanup on script exit
trap cleanup EXIT

# Forward the PostgreSQL port to localhost
echo "Setting up port forwarding to PostGIS..."
kubectl port-forward -n iot-monitoring svc/postgis 5433:5432 &
PF_PID=$!

# Wait for port forwarding to be established
echo "Waiting for port forwarding to be ready..."
sleep 5

# Verify port forwarding is working
timeout 5 bash -c 'until nc -z localhost 5433; do sleep 0.5; done' || {
  echo "Error: Port forwarding to PostgreSQL failed!"
  exit 1
}

# Function to run SQL with clear section headers
# Disable pager with PAGER=/bin/cat and set expanded output off
run_query() {
  local title="$1"
  local query="$2"
  echo ""
  echo "===== $title ====="
  PGPASSWORD=postgres PAGER=/bin/cat psql -h localhost -p 5433 -U postgres -d iot_geo_data -X -c "$query" || {
    echo "Query failed: $title"
    # Don't exit on query failure, continue with other tests
  }
  echo ""
}

echo "Testing connection and PostGIS functionality..."

# Check PostGIS version - with shorter output format to avoid pager issues
run_query "PostGIS Version" "SELECT PostGIS_Version();"

# Clear existing data to prevent duplicate key errors on re-runs
run_query "Clearing existing data" "
TRUNCATE sensor_locations CASCADE;
TRUNCATE geo_fences CASCADE;
"

# Insert sample sensor locations
run_query "Inserting sample sensor locations" "
INSERT INTO sensor_locations (sensor_id, name, description, location, installation_date, status)
VALUES 
  ('sensor-001', 'Weather Station Alpha', 'Temperature and humidity sensor', 
   ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography, 
   '2023-01-15 08:00:00+00', 'active'),
  ('sensor-002', 'Weather Station Beta', 'Wind and precipitation sensor', 
   ST_SetSRID(ST_MakePoint(-122.4099, 37.7895), 4326)::geography, 
   '2023-01-20 09:30:00+00', 'active'),
  ('sensor-003', 'Weather Station Gamma', 'Air quality sensor', 
   ST_SetSRID(ST_MakePoint(-122.4330, 37.7616), 4326)::geography, 
   '2023-02-05 11:15:00+00', 'active');

SELECT sensor_id, name, ST_AsText(location::geometry) as location FROM sensor_locations;
"

# Create a geo-fence
run_query "Creating a geo-fence" "
INSERT INTO geo_fences (name, description, boundary)
VALUES (
  'Downtown Monitoring Zone', 
  'Central business district monitoring area',
  ST_Buffer(
    ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326)::geography, 
    2000 -- 2km radius
  )
);

SELECT fence_id, name FROM geo_fences;
"

# Query sensors within the geo-fence
run_query "Finding sensors within geo-fence" "
SELECT 
  s.sensor_id, 
  s.name, 
  ROUND(ST_Distance(s.location, g.boundary)::numeric, 2) as distance_to_boundary_m
FROM 
  sensor_locations s, 
  geo_fences g
WHERE 
  ST_DWithin(s.location, g.boundary, 5000) -- Find sensors within 5km of boundary
  AND g.name = 'Downtown Monitoring Zone'
ORDER BY
  distance_to_boundary_m;
"

# Find closest sensor to a point
run_query "Finding closest sensor to point" "
SELECT 
  sensor_id, 
  name, 
  ROUND(ST_Distance(
    location, 
    ST_SetSRID(ST_MakePoint(-122.4099, 37.7895), 4326)::geography
  )::numeric, 2) as distance_m
FROM 
  sensor_locations
ORDER BY 
  location <-> ST_SetSRID(ST_MakePoint(-122.4099, 37.7895), 4326)::geography
LIMIT 1;
"

# Calculate area of geo-fence
run_query "Calculate area of geo-fence" "
SELECT 
  name, 
  ROUND(ST_Area(boundary)::numeric / 1000000, 2) as area_sq_km
FROM 
  geo_fences;
"

echo "All tests completed."

# Cleanup happens automatically thanks to the trap