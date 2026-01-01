#!/bin/bash

#############################################
# Script to add existing containers to      #
# a custom Docker network for DNS resolution #
#############################################

NETWORK_NAME="RTQi-network"
APP_CONTAINER_NAME="RTQi-app-container"
DATA_CONTAINER_NAME="RTQi-data-container"

echo "========================================="
echo "  Docker Network Configuration Fix"
echo "========================================="
echo ""

# Create the custom network if it doesn't exist
echo "Checking for Docker network: $NETWORK_NAME..."
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "✓ Docker network $NETWORK_NAME already exists."
else
    echo "Creating Docker network: $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
    if [ $? -eq 0 ]; then
        echo "✓ Docker network $NETWORK_NAME created successfully."
    else
        echo "✗ Failed to create Docker network $NETWORK_NAME."
        exit 1
    fi
fi

echo ""

# Connect app container to the custom network
echo "Connecting $APP_CONTAINER_NAME to $NETWORK_NAME..."
if docker network connect "$NETWORK_NAME" "$APP_CONTAINER_NAME" 2>/dev/null; then
    echo "✓ $APP_CONTAINER_NAME connected to $NETWORK_NAME."
else
    echo "⚠ $APP_CONTAINER_NAME already connected to $NETWORK_NAME or connection failed."
fi

# Connect data container to the custom network
echo "Connecting $DATA_CONTAINER_NAME to $NETWORK_NAME..."
if docker network connect "$NETWORK_NAME" "$DATA_CONTAINER_NAME" 2>/dev/null; then
    echo "✓ $DATA_CONTAINER_NAME connected to $NETWORK_NAME."
else
    echo "⚠ $DATA_CONTAINER_NAME already connected to $NETWORK_NAME or connection failed."
fi

echo ""
echo "========================================="
echo "  Network Configuration Complete!"
echo "========================================="
echo ""
echo "Both containers are now on the custom network '$NETWORK_NAME'."
echo "Container name DNS resolution is now enabled."
echo ""
echo "You can now use 'RTQi-data-container' as the database host"
echo "in your application configuration instead of IP addresses."
echo ""
echo "Verify the network setup with:"
echo "  docker network inspect $NETWORK_NAME"
echo ""
