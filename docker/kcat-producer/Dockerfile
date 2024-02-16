FROM ubuntu:latest

# Install kcat, jq, and other necessary utilities
RUN apt-get update && \
    apt-get install -y kafkacat jq && \
    ln -s /usr/bin/kafkacat /usr/bin/kcat && \
    apt-get install -y wget openjdk-11-jdk-headless && \
    rm -rf /var/lib/apt/lists/*

# Set the Kafka version and installation directory
ENV KAFKA_VERSION="3.6.0"
ENV KAFKA_HOME="/opt/kafka"

# Download and extract Kafka binaries
RUN wget -q "https://downloads.apache.org/kafka/$KAFKA_VERSION/kafka_2.13-$KAFKA_VERSION.tgz" -O /tmp/kafka.tgz && \
    mkdir -p "$KAFKA_HOME" && \
    tar -xzf /tmp/kafka.tgz -C "$KAFKA_HOME" --strip-components=1 && \
    rm /tmp/kafka.tgz 

# Add Kafka command-line tools to PATH
ENV PATH="$KAFKA_HOME/bin:$PATH"

WORKDIR /app
COPY produce_ratings.sh /app/produce_ratings.sh

# Make the script executable
RUN chmod +x /app/produce_ratings.sh

# Run the script when the container starts
ENTRYPOINT ["/bin/bash", "/app/produce_ratings.sh"]
