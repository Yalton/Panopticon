import RPi.GPIO as GPIO
import board
import adafruit_bmp280
import requests
import logging
import time
import json
import os
from datetime import datetime

class SensorManager:
    def __init__(self, pir_pin=17, temp_sensor_address=0x77):
        """Initialize sensor manager with specified pins and addresses"""
        self.PIR_PIN = pir_pin
        self.temp_sensor_address = temp_sensor_address
        self.temp_sensor = None
        self.motion_detected = False
        self.last_temp_reading = 0
        self.temp_interval = 5  # seconds between regular temp readings
        self.location = None
        
        # Set up storage
        if not os.path.exists("sensor_data"):
            os.makedirs("sensor_data")
    
    def initialize(self):
        """Initialize all sensors and get location"""
        # Get location
        self.location = self.get_location()
        logging.info(f"System location: {self.location}")
        
        # Set up GPIO for motion sensor
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.PIR_PIN, GPIO.IN)
        
        # Set up BMP280 temperature/pressure sensor
        i2c = board.I2C()
        try:
            self.temp_sensor = adafruit_bmp280.Adafruit_BMP280_I2C(i2c, address=self.temp_sensor_address)
            self.temp_sensor.sea_level_pressure = 1013.25
            logging.info("Temperature sensor initialized")
        except Exception as e:
            logging.error(f"Error initializing temperature sensor: {str(e)}")
            self.temp_sensor = None
        
        logging.info("Motion sensor initializing...")
        time.sleep(2)  # Give PIR sensor time to initialize
        logging.info("All sensors ready!")
        
        self.last_temp_reading = time.time()
        return True
    
    def check_motion(self):
        """Check motion sensor and return event data if motion is detected"""
        motion_detected_now = GPIO.input(self.PIR_PIN)
        
        # Only trigger when motion is first detected
        if motion_detected_now and not self.motion_detected:
            self.motion_detected = True
            current_time = self.get_time()
            logging.info(f"Motion detected at {current_time}")
            
            # Read temperature when motion is detected
            temp_data = self.read_temperature()
            logging.info(f"Motion triggered temperature reading: {temp_data}")
            
            # Create event record
            event = {
                "timestamp": current_time,
                "event": "motion_detected",
                "location": self.location,
                "sensor_data": temp_data
            }
            
            # Save to JSON file
            filename = f"sensor_data/event_{int(time.time())}.json"
            with open(filename, 'w') as f:
                json.dump(event, f, indent=2)
                
            return event
        
        # Reset motion detected flag when no motion
        if not motion_detected_now:
            self.motion_detected = False
            
        return None
    
    def check_temperature(self):
        """Check if it's time for a regular temperature reading"""
        current_time = time.time()
        
        if current_time - self.last_temp_reading > self.temp_interval:
            self.last_temp_reading = current_time
            temp_data = self.read_temperature()
            time_str = self.get_time()
            logging.info(f"Temperature reading: {temp_data}")
            
            # Create regular reading record
            reading = {
                "timestamp": time_str,
                "event": "regular_reading",
                "location": self.location,
                "sensor_data": temp_data
            }
            
            # Append to daily log file
            day_filename = f"sensor_data/daily_{datetime.now().strftime('%Y-%m-%d')}.json"
            
            # Check if file exists and has content
            if os.path.exists(day_filename) and os.path.getsize(day_filename) > 0:
                try:
                    with open(day_filename, 'r') as f:
                        day_data = json.load(f)
                        if not isinstance(day_data, list):
                            day_data = [day_data]
                except:
                    day_data = []
            else:
                day_data = []
            
            day_data.append(reading)
            
            with open(day_filename, 'w') as f:
                json.dump(day_data, f, indent=2)
                
            return reading
        
        return None
    
    def cleanup(self):
        """Clean up GPIO resources"""
        GPIO.cleanup()
        logging.info("GPIO resources cleaned up")
    
    def get_time(self):
        """Get current system time in formatted string"""
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def get_location(self):
        """Get approximate location based on IP address"""
        try:
            response = requests.get("https://ipinfo.io/json", timeout=5)
            if response.status_code == 200:
                data = response.json()
                location = {
                    "city": data.get("city", "Unknown"),
                    "region": data.get("region", "Unknown"),
                    "country": data.get("country", "Unknown"),
                    "loc": data.get("loc", "Unknown")
                }
                return location
            else:
                return {"error": "Could not retrieve location data"}
        except Exception as e:
            logging.error(f"Error getting location: {str(e)}")
            return {"error": "Connection error"}

    def read_temperature(self):
        """Read data from temperature/pressure sensor"""
        if self.temp_sensor is None:
            return {"error": "Temperature sensor not available"}
        
        try:
            return {
                "temperature_c": round(self.temp_sensor.temperature, 1),
                "temperature_f": round((self.temp_sensor.temperature * 9/5) + 32, 1),
                "pressure_hpa": round(self.temp_sensor.pressure, 1),
                "altitude_m": round(self.temp_sensor.altitude, 2)
            }
        except Exception as e:
            logging.error(f"Error reading temperature sensor: {str(e)}")
            return {"error": "Could not read temperature data"}