import json
import logging
import random
import time

from paho.mqtt import client as mqtt_client

class client:
    BROKER = 'mqtt.eclipseprojects.io'
    PORT = 1883#1883 8000
    TOPIC = "test/test"
    # generate client ID with pub prefix randomly
    CLIENT_ID = f'TEST_PI_CLIENT'#f'python-mqtt-tls-pub-sub-{random.randint(0, 1000)}'


    #IDK ABOUT THESE leaving in for now
    FIRST_RECONNECT_DELAY = 1
    RECONNECT_RATE = 2
    MAX_RECONNECT_COUNT = 12
    MAX_RECONNECT_DELAY = 60

    FLAG_EXIT = False

    def __init__(self):
        print("====Starting Pi publisher====")
        print("Client ID: ",self.CLIENT_ID)
        print("Broker: ", self.BROKER)
        print("Topic: ", self.TOPIC)
        print("=============================")



    #callback for on connect
    def on_connect(client, userdata, flags, rc):
        if rc == 0 and client.is_connected():
            print("Connected to MQTT Broker!")
            #client.subscribe(TOPIC)
        else:
            print(f'Failed to connect, return code {rc}')

    #call back for when msg is recived
    def on_message(client, userdata, msg):
        print(f'Received `{msg.payload.decode()}` from `{msg.topic}` topic')
    
    #connect to broker
    def connect(self):
        client = mqtt_client.Client(mqtt_client.CallbackAPIVersion.VERSION2, client_id = self.CLIENT_ID)
        #client.username_pw_set(self.USERNAME, self.PASSWORD)
        #client.tls_set(client.ssl.PROTOCOL_TLS)
        client.connect(self.BROKER, self.PORT, keepalive=120)
        client.subscribe(self.TOPIC)

        print("...successfully connected to broker...") #probably get rid of once on_connect call back work
        return client
        
    #publish to broker
    def send(self,client,payload):
        # msg_count = 0
        # while not FLAG_EXIT:
        #     msg_dict = {
        #         'msg': payload
        #     }
        #     msg = json.dumps(msg_dict)
        #     if not client.is_connected():
        #         logging.error("publish: MQTT client is not connected!")
        #         time.sleep(1)
        #         continue
        #     result = client.publish(self.TOPIC, msg)
        #     # result: [0, 1]
        #     status = result[0]
        #     if status == 0:
        #         print(f'Send `{msg}` to topic `{TOPIC}`')
        #     else:
        #         print(f'Failed to send message to topic {TOPIC}')
        #     msg_count += 1
        #     time.sleep(1)
        result = client.publish(self.TOPIC, payload=payload,qos=1)
        status = result[0]
        if status == 0:
                 print(f'Succsesfully sent `{payload}` to topic `{self.TOPIC}`')
        else:
             print(f'Failed to send message to topic {self.TOPIC}')



    # def run():
    #     logging.basicConfig(format='%(asctime)s - %(levelname)s: %(message)s',
    #                         level=logging.DEBUG)
    #     client = connect()
    #     client.loop_start()
    #     time.sleep(1)
    #     if client.is_connected():
    #         publish(client)
    #     else:
    #         client.loop_stop() 
