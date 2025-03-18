import time
import logging
from datetime import datetime
from mqtt_client import MQTTClient


def main():
    """Main application function"""
    # Initialize MQTT client
    mqtt = MQTTClient()
    if not mqtt.connect():
        print("Failed to start MQTT client. Continuing without messaging capability.")
    
    try:
        while True:
            print("\nsending test message")
            mqtt.send("{'temperature_c': 16.9, 'temperature_f': 62.5, 'pressure_hpa': 997.4, 'altitude_m': 133.18}")
            
            time.sleep(5)  # Small delay between checks
            
    except KeyboardInterrupt:
        logging.info("Program terminated by user")
    except Exception as e:
        logging.error(f"Unexpected error: {str(e)}")
    finally:
        # Clean up
        mqtt.disconnect()
        logging.info("Cleanup completed, program exited")

if __name__ == "__main__":
    main()