#!/bin/bash

####################################
# Composer Install Script for App #
####################################

# Get the app container name from containers-names.txt
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINERS_FILE="$SCRIPT_DIR/../out/containers-names.txt"

if [ ! -f "$CONTAINERS_FILE" ]; then
    echo "Error: containers-names.txt not found at $CONTAINERS_FILE"
    exit 1
fi

# Read the first line (app container name)
APP_CONTAINER_NAME=$(head -n 1 "$CONTAINERS_FILE" | tr -d '\r\n')

if [ -z "$APP_CONTAINER_NAME" ]; then
    echo "Error: Could not read app container name from containers-names.txt"
    exit 1
fi

echo "======================================"
echo "App Container Composer Install"
echo "======================================"
echo "Container: $APP_CONTAINER_NAME"
echo ""

# Check if container is running
CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER_NAME" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Container '$APP_CONTAINER_NAME' not found"
    exit 1
fi

if [ "$CONTAINER_STATUS" != "running" ]; then
    echo "Error: Container '$APP_CONTAINER_NAME' is not running (status: $CONTAINER_STATUS)"
    exit 1
fi

echo "✓ Container is running"

# Determine the project root inside the container
# Based on the Dockerfile-app, it's /var/www/html
PROJECT_ROOT="/var/www/html"

echo "Project root: $PROJECT_ROOT"
echo ""

# Check if composer is installed in the container
echo "Checking for Composer installation..."
if docker exec "$APP_CONTAINER_NAME" which composer > /dev/null 2>&1; then
    COMPOSER_PATH=$(docker exec "$APP_CONTAINER_NAME" which composer)
    echo "✓ Composer found at: $COMPOSER_PATH"
else
    echo "✗ Composer is not installed in the container"
    echo "  Composer installation is included in Dockerfile-app"
    echo "  Please rebuild the container with composer installed"
    exit 1
fi

# Check if composer.json exists in the project root
echo ""
echo "Checking for composer.json..."
if docker exec "$APP_CONTAINER_NAME" test -f "$PROJECT_ROOT/composer.json"; then
    echo "✓ composer.json found at: $PROJECT_ROOT/composer.json"
else
    echo "✗ composer.json not found at: $PROJECT_ROOT/composer.json"
    echo "  No dependencies to install"
    exit 0
fi

# Run composer install
echo ""
echo "Running composer install..."
echo "======================================"

docker exec -w "$PROJECT_ROOT" "$APP_CONTAINER_NAME" composer install --no-interaction --prefer-dist --optimize-autoloader

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "✓ Composer install completed successfully"
    echo "======================================"
else
    echo ""
    echo "======================================"
    echo "✗ Composer install failed"
    echo "======================================"
    exit 1
fi
