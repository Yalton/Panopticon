# Sensor Monitoring System Installation Guide

This guide provides instructions for installing and setting up the Raspberry Pi sensor monitoring system.

## Requirements

- Raspberry Pi (any model) with Raspberry Pi OS installed
- Internet connection on the Raspberry Pi
- BMP280 temperature/pressure sensor
- PIR motion sensor
- Jumper wires

## Installation Steps

### 1. Install System Dependencies

First, install the required system packages:

```bash
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv i2c-tools python3-rpi.gpio git
```

### 2. Enable I2C Interface

Enable the I2C interface on your Raspberry Pi:

```bash
sudo raspi-config
```

Navigate to "Interface Options" > "I2C" > "Yes" to enable I2C.

### 3. Clone the Repository

Clone the repository to your Raspberry Pi:

```bash
git clone https://github.com/yourusername/sensor-monitoring.git
cd sensor-monitoring
```

_Note: Replace the GitHub URL with your actual repository URL._

### 4. Create a Virtual Environment

Create and activate a Python virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

### 5. Install Python Dependencies

Install the required Python packages:

```bash
pip install -r requirements.txt
```

If you don't have a requirements.txt file, you can create one with the following content:

```
adafruit-circuitpython-bmp280==2.6.16
adafruit-blinka==8.20.1
paho-mqtt==2.2.1
requests==2.31.0
RPi.GPIO==0.7.1
```

### 6. Verify Sensor Connections

Before running the application, verify your sensor connections:

```bash
sudo i2cdetect -y 1
```

You should see your BMP280 sensor appear at address 0x76 or 0x77.

### 7. Run the Application

Run the sensor monitoring application:

```bash
python main_app.py
```

### 8. Setting up as a Service (Optional)

To run the application as a service that starts automatically on boot:

```bash
sudo nano /etc/systemd/system/sensor-monitor.service
```

Add the following content:

```
[Unit]
Description=Sensor Monitoring Service
After=multi-user.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/sensor-monitoring
ExecStart=/home/pi/sensor-monitoring/venv/bin/python /home/pi/sensor-monitoring/main_app.py
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

_Note: Update paths as necessary based on your installation location._

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable sensor-monitor.service
sudo systemctl start sensor-monitor.service
```

Check service status:

```bash
sudo systemctl status sensor-monitor.service
```

## Testing

To test simply run

```
python testBroker.py
```

View on AWS IOT Core test client page. The script publishes and subscribes to a topic and will send/print messages accordingly

## Troubleshooting

### I2C Issues

- If your BMP280 sensor is not detected, check your wiring connections.
- Ensure the I2C interface is enabled in `raspi-config`.

### GPIO Issues

- If the PIR sensor does not trigger, verify your wiring connections.
- Check that your user has permission to access GPIO pins.

### Python Environment Issues

- If you encounter Python import errors, ensure you're running within the activated virtual environment.
- Verify all dependencies are installed correctly with `pip list`.

### MQTT Issues

- If MQTT messages aren't being sent, check your broker connection details.
- Verify network connectivity to your MQTT broker.

## Customization

Edit the configuration values in the code files to customize:

- MQTT broker information in `mqtt_client.py`
- Sensor pins and reading intervals in `sensor_utils.py`
- Data storage location in `sensor_utils.py`
