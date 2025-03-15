#!/usr/bin/env python3
import sys
import traceback
import json
import os
import time
import yaml
import logging
import random
import datetime
import psycopg2
from psycopg2 import extras

# Logging configuration
logging.basicConfig(
    level=logging.INFO, 
    format='%(asctime)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s'
)
logger = logging.getLogger('mqtt-bridge')

# Load configuration
def load_config():
    config_path = os.environ.get('CONFIG_PATH', '/app/config/config.yaml')
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        return config
    except Exception as e:
        logger.error(f"Error loading configuration: {e}")
        raise

# Database connection
def get_db_connection(config):
    try:
        user = os.environ.get('DB_USER', 'postgres')
        password = os.environ.get('DB_PASSWORD', 'postgres')
        
        host = config.get('database', {}).get('host', 'timescaledb')
        port = config.get('database', {}).get('port', 5432)
        dbname = config.get('database', {}).get('name', 'sensor_data')
        
        conn = psycopg2.connect(
            host=host,
            port=port,
            dbname=dbname,
            user=user,
            password=password
        )
        return conn
    except Exception as e:
        logger.error(f"Database connection error: {e}")
        raise

# Insert sensor data
def insert_sensor_data(conn, sensor_id, temperature, humidity, pressure, timestamp=None):
    if timestamp is None:
        timestamp = datetime.datetime.now()
        
    try:
        cur = conn.cursor()
        
        # Insert temperature
        cur.execute("""
        INSERT INTO sensor_data (time, device_id, sensor_type, value, location_id)
        VALUES (%s, %s, %s, %s, %s)
        """, (timestamp, sensor_id, 'temperature', temperature, 'default'))
        
        # Insert humidity
        cur.execute("""
        INSERT INTO sensor_data (time, device_id, sensor_type, value, location_id)
        VALUES (%s, %s, %s, %s, %s)
        """, (timestamp, sensor_id, 'humidity', humidity, 'default'))
        
        # Insert pressure
        cur.execute("""
        INSERT INTO sensor_data (time, device_id, sensor_type, value, location_id)
        VALUES (%s, %s, %s, %s, %s)
        """, (timestamp, sensor_id, 'pressure', pressure, 'default'))
        
        conn.commit()
        cur.close()
        
        logger.info(f"Inserted data for sensor {sensor_id}: temp={temperature:.1f}, humidity={humidity:.1f}, pressure={pressure:.1f}")
    except Exception as e:
        logger.error(f"Error inserting sensor data for {sensor_id}: {e}")
        conn.rollback()
        raise

# Development mode data generation
def development_mode(config):
    dev_config = config.get('development', {})
    interval = dev_config.get('sample_interval_seconds', 10)
    sensors = dev_config.get('sample_sensors', [])
    
    # Ensure some default sensors if none are configured
    if not sensors:
        sensors = [
            {
                "id": "sensor001", 
                "temperature_min": 18.0, 
                "temperature_max": 28.0,
                "humidity_min": 30.0, 
                "humidity_max": 80.0,
                "pressure_min": 980.0, 
                "pressure_max": 1020.0
            },
            {
                "id": "sensor002", 
                "temperature_min": 20.0, 
                "temperature_max": 25.0,
                "humidity_min": 40.0, 
                "humidity_max": 70.0,
                "pressure_min": 990.0, 
                "pressure_max": 1010.0
            }
        ]
    
    # Establish database connection once
    conn = get_db_connection(config)
    
    try:
        logger.info(f"Starting development mode with {len(sensors)} simulated sensors")
        logger.info(f"Data will be generated every {interval} seconds")
        
        while True:
            for sensor in sensors:
                try:
                    sensor_id = sensor.get('id')
                    
                    # Generate realistic sensor data
                    temperature = sensor.get('temperature_min', 20.0) + random.uniform(0, sensor.get('temperature_max', 25.0) - sensor.get('temperature_min', 20.0))
                    humidity = sensor.get('humidity_min', 40.0) + random.uniform(0, sensor.get('humidity_max', 60.0) - sensor.get('humidity_min', 40.0))
                    pressure = sensor.get('pressure_min', 1000.0) + random.uniform(0, sensor.get('pressure_max', 1020.0) - sensor.get('pressure_min', 1000.0))
                    
                    # Insert the data
                    insert_sensor_data(conn, sensor_id, temperature, humidity, pressure)
                
                except Exception as sensor_err:
                    logger.error(f"Error processing sensor {sensor.get('id')}: {sensor_err}")
            
            # Sleep until next interval
            time.sleep(interval)
    
    except KeyboardInterrupt:
        logger.info("Development mode stopped by user")
    finally:
        conn.close()

# Main function
def main():
    try:
        # Load configuration
        config = load_config()
        
        # Determine mode
        mode = config.get('bridge', {}).get('mode', 'production').lower()
        logger.info(f"Starting MQTT bridge in {mode} mode")
        
        # Run appropriate mode
        if mode == 'development':
            development_mode(config)
        else:
            logger.warning("Production mode not implemented")
            while True:
                time.sleep(60)
    
    except Exception as e:
        logger.error(f"Unhandled exception: {e}")
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    main()