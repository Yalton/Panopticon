import json
import logging
from dotenv import load_dotenv
import os
from paho.mqtt import client as mqtt_client


class MQTTClient:
    def __init__(self, broker='mqtt.eclipseprojects.io', port=8883, topic="test/test", client_id='TEST_PI_CLIENT'):
        
        #TODO: read in from env 
        load_dotenv()
        
        self.BROKER = os.getenv("BROKER")
        self.PORT = port
        self.TOPIC = topic
        self.CLIENT_ID = os.getenv("CLIENTID")

        self.ca_cert_path = os.getenv("CA_CERT")
        self.client_cert_path = os.getenv("CLIENT_CERT")
        self.client_priv_key_path = os.getenv("CLIENT_PRIV_KEY")

        print(self.ca_cert_path)
        print(self.client_cert_path)
        print(self.client_priv_key_path)
        
        logging.info("====Starting MQTT Client====")
        logging.info(f"Client ID: {self.CLIENT_ID}")
        logging.info(f"Broker: {self.BROKER}")
        logging.info(f"Topic: {self.TOPIC}")
        logging.info("===========================")
        
        self.client = None
    
    def on_connect(self, client, userdata, flags, rc, properties=None):
        logging.info("Connected to MQTT Broker!")
        self.client.subscribe(self.TOPIC)
       

    def on_message(self,client, userdata, msg):
        print(msg.payload)
        logging.info('received message: topic: %s payload: %s', msg.topic, msg.payload)
        #additonal logic for on message behavior here 
    
    def connect(self):

        #TODO: refactor to work with aws deployment

        self.client = mqtt_client.Client(mqtt_client.CallbackAPIVersion.VERSION2, protocol=mqtt_client.MQTTv5, client_id=self.CLIENT_ID)
        self.client.tls_set(
            ca_certs=self.ca_cert_path,
            certfile=self.client_cert_path,
            keyfile=self.client_priv_key_path,
            tls_version=2)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
      
        try:
            self.client.connect(self.BROKER, self.PORT, keepalive=120)
            print(self.client)
            self.client.loop_start()
            return True
        except Exception as e:
            logging.error(f"Connection to MQTT broker failed: {str(e)}")
            return False
    
    def send(self, payload):
        if not self.client or not self.client.is_connected():
            logging.error("INSIDE SEND MQTT client is not connected!")
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