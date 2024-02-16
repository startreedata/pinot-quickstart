#!/bin/bash

# Set the path to your movies.json file
MOVIES_FILE="${MOVIES_FILE:-/app/movies.json}"

# Set the Kafka topic to produce to
KAFKA_TOPIC="${KAFKA_TOPIC:-your_kafka_topic}"
KAFKA_TOPIC_PARTITIONS="${KAFKA_TOPIC_PARTITIONS:-10}"

# Set the Kafka broker address
KAFKA_BROKER="${KAFKA_BROKER:-your_kafka_broker_address:9092}"

# Set the limit to the number of lines in the file
LIMIT="${LIMIT:-$(wc -l < "$MOVIES_FILE")}"

# Set the log level (e.g., DEBUG, INFO, NONE)
LOG_LEVEL="${LOG_LEVEL:-NONE}"

# Batch configuration
BATCH_NUM_MESSAGES=1000
LINGER_MS=1000

# Function to log debug messages
log_debug() {
    if [ "$LOG_LEVEL" = "DEBUG" ]; then
        echo "DEBUG: $1"
    fi
}

# Find the minimum and maximum movie IDs
MIN_ID=$(jq -r '.movieId' "$MOVIES_FILE" | sort -n | head -n1)
MAX_ID=$(jq -r '.movieId' "$MOVIES_FILE" | sort -n | tail -n1)

# Start the timer
START_TIME=$(date +%s)
LAST_REPORT_TIME=$START_TIME
MESSAGES_PRODUCED=0

# Print out environment variables for debugging
echo "MOVIES_FILE: $MOVIES_FILE"
echo "KAFKA_TOPIC: $KAFKA_TOPIC"
echo "KAFKA_BROKER: $KAFKA_BROKER"
echo "LIMIT: $LIMIT"
echo "MIN_ID": $MIN_ID
echo "MAX_ID": $MAX_ID

# Wait for Kafka broker to be ready
echo "Waiting for Kafka broker to be ready..."
while ! kafkacat -b "$KAFKA_BROKER" -L &>/dev/null; do
    echo "Kafka broker not ready yet, retrying in 5 seconds..."
    sleep 5
done
echo "Kafka broker is ready!"

# Create the topic with 10 partitions if it doesn't exist
if ! kafkacat -b "$KAFKA_BROKER" -L | grep -q "topic \"$KAFKA_TOPIC\""; then
    echo "Creating topic '$KAFKA_TOPIC' with '$KAFKA_TOPIC_PARTITIONS' partitions..."
    kafka-topics.sh --create --bootstrap-server "$KAFKA_BROKER" --replication-factor 1 --partitions "$KAFKA_TOPIC_PARTITIONS" --topic "$KAFKA_TOPIC"
fi

# Read the movie IDs into an array
mapfile -t MOVIE_IDS < <(jq -r '.movieId' "$MOVIES_FILE")

# Get the number of movies
NUM_MOVIES=${#MOVIE_IDS[@]}

# Generate and produce ratings
{ for ((i=1; i<=LIMIT; i++)); do
   # Select a random movie ID
   movieId=${MOVIE_IDS[RANDOM % NUM_MOVIES]}

    # Generate a random rating between 0.0 and 10.0
    rating=$(awk -v min=0 -v max=10 'BEGIN{srand(); print min+rand()*(max-min)}')

    # Generate a timestamp in milliseconds
    ratingTime=$(($(date +%s)*1000))

    # Create the JSON object
    data=$(jq -n -c --arg movieId "$movieId" --arg rating "$rating" --arg ratingTime "$ratingTime" '{movieId: ($movieId | tonumber), rating: ($rating | tonumber), ratingTime: ($ratingTime | tonumber)}')

   # Log the JSON object if debugging is enabled
   log_debug "Producing JSON object: $data for key $movieId"

    # Output the JSON object with the movieId as the key
    echo "$movieId:$data"
 
   # Increment the messages produced counter
   ((MESSAGES_PRODUCED++))

   # Every 5 seconds, report the messages per second
   CURRENT_TIME=$(date +%s)
   if [ $((CURRENT_TIME - LAST_REPORT_TIME)) -ge 5 ]; then
       ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
       if [ "$ELAPSED_TIME" -gt 0 ]; then
           MESSAGES_PER_SECOND=$((MESSAGES_PRODUCED / ELAPSED_TIME))
           echo "Produced $MESSAGES_PRODUCED messages in $ELAPSED_TIME seconds ($MESSAGES_PER_SECOND messages per second)" >&2
       fi
       LAST_REPORT_TIME=$CURRENT_TIME
   fi
done
 } | kafkacat -b "$KAFKA_BROKER" -t "$KAFKA_TOPIC" -P -K : -X batch.num.messages="$BATCH_NUM_MESSAGES" -X linger.ms="$LINGER_MS"
 

# Final report
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
if [ "$ELAPSED_TIME" -gt 0 ]; then
    MESSAGES_PER_SECOND=$((MESSAGES_PRODUCED / ELAPSED_TIME))
    echo "Final report: Produced $MESSAGES_PRODUCED messages in $ELAPSED_TIME seconds ($MESSAGES_PER_SECOND messages per second)"
else
    echo "Produced $MESSAGES_PRODUCED messages in less than 1 second"
fi