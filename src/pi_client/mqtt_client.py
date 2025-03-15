import json
import logging
from paho.mqtt import client as mqtt_client

class MQTTClient:
    def __init__(self, broker='mqtt.eclipseprojects.io', port=1883, topic="test/test", client_id='TEST_PI_CLIENT'):
        self.BROKER = broker
        self.PORT = port
        self.TOPIC = topic
        self.CLIENT_ID = client_id
        
        logging.info("====Starting MQTT Client====")
        logging.info(f"Client ID: {self.CLIENT_ID}")
        logging.info(f"Broker: {self.BROKER}")
        logging.info(f"Topic: {self.TOPIC}")
        logging.info("===========================")
        
        self.client = None
    
    def on_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0 and client.is_connected():
            logging.info("Connected to MQTT Broker!")
        else:
            logging.error(f'Failed to connect to MQTT broker, return code {rc}')
    
    def connect(self):
        self.client = mqtt_client.Client(mqtt_client.CallbackAPIVersion.VERSION2, client_id=self.CLIENT_ID)
        self.client.on_connect = self.on_connect
        try:
            self.client.connect(self.BROKER, self.PORT, keepalive=120)
            self.client.loop_start()
            return True
        except Exception as e:
            logging.error(f"Connection to MQTT broker failed: {str(e)}")
            return False
    
    def send(self, payload):
        if not self.client or not self.client.is_connected():
            logging.error("MQTT client is not connected!")
            return False
        
        try:
            # Convert dict to JSON string if payload is a dict
            if isinstance(payload, dict):
                payload = json.dumps(payload)
                
            result = self.client.publish(self.TOPIC, payload=payload, qos=1)
            status = result[0]
            if status == 0:
                logging.info(f"Successfully sent message to topic {self.TOPIC}")
                return True
            else:
                logging.error(f"Failed to send message to topic {self.TOPIC}")
                return False
        except Exception as e:
            logging.error(f"Error sending MQTT message: {str(e)}")
            return False
    
    def disconnect(self):
        if self.client:
            self.client.loop_stop()
            self.client.disconnect()
            logging.info("Disconnected from MQTT broker")