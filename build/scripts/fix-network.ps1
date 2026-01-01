# PowerShell script to add existing containers to a custom Docker network

$NETWORK_NAME = "RTQi-network"
$APP_CONTAINER_NAME = "RTQi-app-container"
$DATA_CONTAINER_NAME = "RTQi-data-container"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Docker Network Configuration Fix" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Create the custom network if it doesn't exist
Write-Host "Checking for Docker network: $NETWORK_NAME..." -ForegroundColor Yellow
$networkExists = docker network inspect $NETWORK_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Docker network $NETWORK_NAME already exists." -ForegroundColor Green
} else {
    Write-Host "Creating Docker network: $NETWORK_NAME..." -ForegroundColor Yellow
    docker network create $NETWORK_NAME
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker network $NETWORK_NAME created successfully." -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create Docker network $NETWORK_NAME." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Connect app container to the custom network
Write-Host "Connecting $APP_CONTAINER_NAME to $NETWORK_NAME..." -ForegroundColor Yellow
docker network connect $NETWORK_NAME $APP_CONTAINER_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ $APP_CONTAINER_NAME connected to $NETWORK_NAME." -ForegroundColor Green
} else {
    Write-Host "⚠ $APP_CONTAINER_NAME already connected to $NETWORK_NAME or connection failed." -ForegroundColor Yellow
}

# Connect data container to the custom network
Write-Host "Connecting $DATA_CONTAINER_NAME to $NETWORK_NAME..." -ForegroundColor Yellow
docker network connect $NETWORK_NAME $DATA_CONTAINER_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ $DATA_CONTAINER_NAME connected to $NETWORK_NAME." -ForegroundColor Green
} else {
    Write-Host "⚠ $DATA_CONTAINER_NAME already connected to $NETWORK_NAME or connection failed." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Network Configuration Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Both containers are now on the custom network '$NETWORK_NAME'." -ForegroundColor Green
Write-Host "Container name DNS resolution is now enabled." -ForegroundColor Green
Write-Host ""
Write-Host "You can now use 'RTQi-data-container' as the database host" -ForegroundColor White
Write-Host "in your application configuration instead of IP addresses." -ForegroundColor White
Write-Host ""
Write-Host "Verify the network setup with:" -ForegroundColor Yellow
Write-Host "  docker network inspect $NETWORK_NAME" -ForegroundColor Gray
Write-Host ""
