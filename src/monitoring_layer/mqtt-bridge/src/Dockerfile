FROM python:3.9-alpine
WORKDIR /app
COPY mqtt-bridge.py /app/
RUN apk add --no-cache postgresql-client gcc musl-dev postgresql-dev && \
    pip install paho-mqtt psycopg2-binary pyyaml awsiotsdk
CMD ["python", "/app/mqtt-bridge.py"]
