#!/bin/bash
docker exec -i connect confluent-hub install confluentinc/kafka-connect-jdbc:latest --component-dir /usr/share/java --no-prompt
docker-compose restart connect