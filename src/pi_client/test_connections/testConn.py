import paho.mqtt.client as mqtt

# Define callback functions (optional, but good practice)
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT Broker!")
    else:
        print(f"Failed to connect, return code {rc}")

def on_publish(client, userdata, mid):
    print(f"Message published (mid: {mid})")

# Create an MQTT client instance
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,client_id ="TEST")

# Assign callback functions
# client.on_connect = on_connect
# client.on_publish = on_publish

# Configure authentication (if needed)
# client.username_pw_set("your_username", "your_password")

# Connect to the MQTT broker
broker_address = "mqtt.eclipseprojects.io"  # Replace with your broker's address
port = 1883  # Default MQTT port
client.connect(broker_address, port)

# Start the MQTT loop (to handle connection and callbacks)
client.loop_start()

# Publish a message
topic = "your/topic"  # Replace with your desired topic
message = "Hello, MQTT!"
qos = 0  # Quality of Service (0, 1, or 2)
client.publish(topic, message, qos)

# Keep the script running for a while to allow publishing
import time
time.sleep(2)

# Stop the MQTT loop and disconnect
client.loop_stop()
client.disconnect()