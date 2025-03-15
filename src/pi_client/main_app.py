import time
import logging
from datetime import datetime
from mqtt_client import MQTTClient
from sensor_utils import SensorManager

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("sensor_log.txt"),
        logging.StreamHandler()
    ]
)

def main():
    """Main application function"""
    logging.info("Starting integrated sensor monitoring system...")
    
    # Initialize MQTT client
    mqtt = MQTTClient()
    if not mqtt.connect():
        logging.error("Failed to start MQTT client. Continuing without messaging capability.")
    
    # Initialize sensors
    sensors = SensorManager()
    sensors.initialize()
    
    try:
        while True:
            # Check for motion events
            motion_event = sensors.check_motion()
            if motion_event:
                mqtt.send(motion_event)
            
            # Check for scheduled temperature readings
            temp_event = sensors.check_temperature()
            if temp_event:
                mqtt.send(temp_event)
            
            time.sleep(0.1)  # Small delay between checks
            
    except KeyboardInterrupt:
        logging.info("Program terminated by user")
    except Exception as e:
        logging.error(f"Unexpected error: {str(e)}")
    finally:
        # Clean up
        sensors.cleanup()
        mqtt.disconnect()
        logging.info("Cleanup completed, program exited")

if __name__ == "__main__":
    main()