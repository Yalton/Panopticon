#import context  # Ensures paho is in PYTHONPATH

import paho.mqtt.subscribe as subscribe

topics = ['test/test']

m = subscribe.simple(topics, hostname="mqtt.eclipseprojects.io", retained=False, msg_count=2)
for a in m:
    print(a.topic)
    print(a.payload)