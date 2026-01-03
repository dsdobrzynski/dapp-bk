#!/bin/bash

##################
# INITIALIZATION #
##################

REBUILD_APP_CONTAINER=0
REBUILD_DATA_CONTAINER=0
IMPORT_DATA=0

for arg in "$@"; do
    if [[ "$arg" == "--rebuild-app" ]]; then
        REBUILD_APP_CONTAINER=1
    fi
    if [[ "$arg" == "--rebuild-data" ]]; then
        REBUILD_DATA_CONTAINER=1
    fi
    if [[ "$arg" == "--import-data" ]]; then
        IMPORT_DATA=1
    fi
done

#################
# PROJECT SETUP #
#################

# Change to project root directory
cd "$(dirname "$0")/../.."

echo "Current directory: $(pwd)"

# Load environment variables from .env
set -a
source .env
set +a

# Get project name from .env
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: You must set PROJECT_NAME in .env. This will be used for naming containers."
    exit 1
fi

# Print summary of arguments and key environment variables
cat <<EOM

============================
  Build Script Configuration
============================
REBUILD_APP_CONTAINER:   $REBUILD_APP_CONTAINER
REBUILD_DATA_CONTAINER:  $REBUILD_DATA_CONTAINER
IMPORT_DATA:             $IMPORT_DATA
PROJECT_NAME:            $PROJECT_NAME
APP_DOCKERFILE:          ${APP_DOCKERFILE}
APP_BASE_IMAGE:          ${APP_BASE_IMAGE}
DATA_REL_DOCKERFILE:         ${DATA_REL_DOCKERFILE}
DATA_REL_BASE_IMAGE:         ${DATA_REL_BASE_IMAGE}
DATA_NONREL_DOCKERFILE:      ${DATA_NONREL_DOCKERFILE}
DATA_NONREL_BASE_IMAGE:      ${DATA_NONREL_BASE_IMAGE}
APP_AWS_CLI_PROFILE:     $APP_AWS_CLI_PROFILE
APP_AWS_REGION:          $APP_AWS_REGION
APP_REPO_NAME:           $APP_REPO_NAME
APP_IMAGE_TAG:           $APP_IMAGE_TAG
DATA_REL_AWS_CLI_PROFILE:    $DATA_REL_AWS_CLI_PROFILE
DATA_REL_AWS_REGION:         $DATA_REL_AWS_REGION
DATA_REL_REPO_NAME:          $DATA_REL_REPO_NAME
DATA_REL_IMAGE_TAG:          $DATA_REL_IMAGE_TAG
============================

EOM

read -p "Continue with these settings? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

####################
# HELPER FUNCTIONS #
####################

# Helper function to check if container name exists (use docker directly)
container_exists() {
    local cname="$1"
    docker ps -a --format '{{.Names}}' | grep -Fxq "$cname"
    return $?
}

##########################
# DOCKER NETWORK SETUP   #
##########################

NETWORK_NAME="$PROJECT_NAME-network"
echo "Checking for Docker network: $NETWORK_NAME..."
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "Docker network $NETWORK_NAME already exists."
else
    echo "Creating Docker network: $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
    if [ $? -eq 0 ]; then
        echo "Docker network $NETWORK_NAME created successfully."
    else
        echo "Failed to create Docker network $NETWORK_NAME."
        exit 1
    fi
fi

#################
# APP CONTAINER #
#################

APP_CONTAINER_NAME="$PROJECT_NAME-app-container"
REBUILD_OR_NEW_APP=0
APP_CONTAINER_SUMMARY=""
if container_exists "$APP_CONTAINER_NAME"; then
    echo "Container $APP_CONTAINER_NAME already exists. Checking status..."
    STATUS=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER_NAME" 2>/dev/null)
    if [[ "$STATUS" == "running" ]]; then
        echo "Container $APP_CONTAINER_NAME is already running."
        APP_CONTAINER_ID=$(docker inspect -f '{{.Id}}' "$APP_CONTAINER_NAME" 2>/dev/null)
        APP_CONTAINER_SUMMARY="App Container:\n  Name: $APP_CONTAINER_NAME\n  Address: http://localhost:$APP_HOST_PORT\n  ID: $APP_CONTAINER_ID"
    else
        echo "Container $APP_CONTAINER_NAME exists but is not running. Starting..."
        docker start "$APP_CONTAINER_NAME"
        STATUS=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" == "running" ]]; then
            echo "Container $APP_CONTAINER_NAME started."
        else
            echo "Failed to start $APP_CONTAINER_NAME."
            exit 1
        fi
    fi
    if [[ "$REBUILD_APP_CONTAINER" == "1" ]]; then
        echo "Rebuilding app container..."
        STATUS=$(docker inspect -f '{{.State.Status}}' "$APP_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" == "running" ]]; then
            docker stop "$APP_CONTAINER_NAME"
        fi
        docker rm -v "$APP_CONTAINER_NAME"
        REBUILD_OR_NEW_APP=1
    fi
else
    REBUILD_OR_NEW_APP=1
fi
if [[ "$REBUILD_OR_NEW_APP" == "1" ]]; then
    # Set application type (default to php-apache if not set)
    if [[ -z "$APP_TYPE" ]]; then
        APP_TYPE="php-apache"
        echo "APP_TYPE not set in .env, defaulting to: $APP_TYPE"
    else
        echo "Using APP_TYPE from .env: $APP_TYPE"
    fi

    # Auto-select Dockerfile based on application type if not explicitly set
    if [[ -z "$APP_DOCKERFILE" ]]; then
        case "$APP_TYPE" in
            php-apache)
                APP_DOCKERFILE="docker/app/Dockerfile-app-php"
                ;;
            node)
                APP_DOCKERFILE="docker/app/Dockerfile-app-node"
                ;;
            python)
                APP_DOCKERFILE="docker/app/Dockerfile-app-python"
                ;;
            java)
                APP_DOCKERFILE="docker/app/Dockerfile-app-java"
                ;;
            *)
                echo "Error: Unsupported APP_TYPE '$APP_TYPE'. Must be php-apache, node, python, or java."
                exit 1
                ;;
        esac
        echo "Auto-selected Dockerfile: $APP_DOCKERFILE"
    else
        echo "Using APP_DOCKERFILE from .env: $APP_DOCKERFILE"
    fi

    # Authenticate via AWS SSO for app (only if profile is set)
    if [[ -n "$APP_AWS_CLI_PROFILE" ]]; then
        echo "Authenticating via AWS SSO for app..."
        aws sso login --profile $APP_AWS_CLI_PROFILE --no-browser
        if [ $? -eq 0 ]; then
            echo "AWS SSO authentication for app successful."
        else
            echo "AWS SSO authentication for app failed."
            echo "If you see 'Cannot perform an interactive login from a non TTY device', run 'aws sso login --profile $APP_AWS_CLI_PROFILE' manually in your terminal before running this script."
            exit 1
        fi

        # Authenticate Docker to AWS ECR
        echo "Authenticating Docker to AWS ECR for app..."
        aws ecr get-login-password --region $APP_AWS_REGION --profile $APP_AWS_CLI_PROFILE | docker login --username AWS --password-stdin $APP_AWS_ACCOUNT_ID.dkr.ecr.$APP_AWS_REGION.amazonaws.com
        if [ $? -eq 0 ]; then
            echo "Docker authenticated to AWS ECR for app successfully."
        else
            echo "Docker authentication to AWS ECR for app failed."
            echo "If you see an SSL certificate error, ensure your system CA certificates are up to date. On Windows, update your system certificates and ensure you have the latest AWS CLI and Python installed."
            exit 1
        fi
    else
        echo "APP_AWS_CLI_PROFILE not set, skipping AWS SSO authentication for app."
    fi

    # Pull or build the app image
    if [[ -z "$APP_AWS_ACCOUNT_ID" || -z "$APP_AWS_REGION" || -z "$APP_REPO_NAME" || -z "$APP_IMAGE_TAG" ]]; then
        echo "Remote app image details not set. Building Docker app image using Dockerfile: $APP_DOCKERFILE..."
        APP_BUILD_ARGS=""
        if [[ -n "$APP_BASE_IMAGE" ]]; then
            APP_BUILD_ARGS="--build-arg BASE_IMAGE=$APP_BASE_IMAGE"
            echo "Using custom app base image: $APP_BASE_IMAGE"
        fi
        docker build -f "$APP_DOCKERFILE" $APP_BUILD_ARGS -t local-build-app-image .
        if [ $? -eq 0 ]; then
            echo "Docker app image built successfully from Dockerfile."
            APP_IMAGE_TO_RUN="local-build-app-image"
        else
            echo "Failed to build Docker app image from Dockerfile."; exit 1
        fi
    else
        echo "Pulling Docker app image..."
        docker pull $APP_AWS_ACCOUNT_ID.dkr.ecr.$APP_AWS_REGION.amazonaws.com/$APP_REPO_NAME:$APP_IMAGE_TAG
        if [ $? -eq 0 ]; then
            echo "Docker app image pulled successfully."
            APP_IMAGE_TO_RUN="$APP_AWS_ACCOUNT_ID.dkr.ecr.$APP_AWS_REGION.amazonaws.com/$APP_REPO_NAME:$APP_IMAGE_TAG"
        else
            echo "Failed to pull Docker app image."; exit 1
        fi
    fi

    # Build app docker run options
    echo "Building app docker run options..."
    DOCKER_RUN_OPTS="-d -p $APP_HOST_PORT:$APP_CONTAINER_PORT --network $NETWORK_NAME"
    if [[ -n "$APP_HOST_VOLUME_PATH" && -n "$APP_CONTAINER_VOLUME_PATH" ]]; then
        DOCKER_RUN_OPTS="$DOCKER_RUN_OPTS -v $APP_HOST_VOLUME_PATH:$APP_CONTAINER_VOLUME_PATH"
        echo "Volume mapping for app enabled: $APP_HOST_VOLUME_PATH -> $APP_CONTAINER_VOLUME_PATH"
    else
        echo "No volume mapping for app configured."
    fi

    # Run the app container with set run options
    echo "Running Docker app container..."
    APP_CONTAINER_ID=$(docker run $DOCKER_RUN_OPTS \
        --name "$APP_CONTAINER_NAME" \
        -e APP_PORT_HOST="$APP_HOST_PORT" \
        -e APP_PORT_CONTAINER="$APP_CONTAINER_PORT" \
        $APP_IMAGE_TO_RUN)
    if [ $? -eq 0 ]; then
        echo "Docker app container started successfully."
        echo "App Container ID: $APP_CONTAINER_ID"
        docker inspect "$APP_CONTAINER_ID"
        APP_CONTAINER_SUMMARY="App Container:\n  Name: $APP_CONTAINER_NAME\n  Address: http://localhost:$APP_HOST_PORT\n  ID: $APP_CONTAINER_ID"
    else
        echo "Failed to start Docker app container."; exit 1
    fi
fi

#################
# DATA CONTAINER #
#################

DATA_REL_CONTAINER_NAME="$PROJECT_NAME-data-container"
REBUILD_OR_NEW_DATA=0
DATA_REL_CONTAINER_SUMMARY=""
if container_exists "$DATA_REL_CONTAINER_NAME"; then
    echo "Container $DATA_REL_CONTAINER_NAME already exists. Checking status..."
    STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
    if [[ "$STATUS" == "running" ]]; then
        echo "Container $DATA_REL_CONTAINER_NAME is already running."
        DATA_REL_CONTAINER_ID=$(docker inspect -f '{{.Id}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
        DATA_REL_CONTAINER_SUMMARY="Data Container:\n  Name: $DATA_REL_CONTAINER_NAME\n  Address: localhost:$DATA_REL_HOST_PORT\n  ID: $DATA_REL_CONTAINER_ID"
    else
        echo "Container $DATA_REL_CONTAINER_NAME exists but is not running. Starting..."
        docker start "$DATA_REL_CONTAINER_NAME"
        STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" == "running" ]]; then
            echo "Container $DATA_REL_CONTAINER_NAME started."
            DATA_REL_CONTAINER_ID=$(docker inspect -f '{{.Id}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
            DATA_REL_CONTAINER_SUMMARY="Data Container:\n  Name: $DATA_REL_CONTAINER_NAME\n  Address: localhost:$DATA_REL_HOST_PORT\n  ID: $DATA_REL_CONTAINER_ID"
        else
            echo "Failed to start $DATA_REL_CONTAINER_NAME."
            exit 1
        fi
    fi
    if [[ "$REBUILD_DATA_CONTAINER" == "1" ]]; then
        echo "Rebuilding data container..."
        STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" == "running" ]]; then
            docker stop "$DATA_REL_CONTAINER_NAME"
        fi
        docker rm -v "$DATA_REL_CONTAINER_NAME"
        REBUILD_OR_NEW_DATA=1
    fi
else
    REBUILD_OR_NEW_DATA=1
fi
if [[ "$REBUILD_OR_NEW_DATA" == "1" ]]; then
    # Set database type (default to postgres if not set)
    if [[ -z "$DATA_REL_TYPE" ]]; then
        DATA_REL_TYPE="postgres"
        echo "DATA_REL_TYPE not set in .env, defaulting to: $DATA_REL_TYPE"
    else
        echo "Using DATA_REL_TYPE from .env: $DATA_REL_TYPE"
    fi

    # Auto-select Dockerfile based on database type if not explicitly set
    if [[ -z "$DATA_REL_DOCKERFILE" ]]; then
        case "$DATA_REL_TYPE" in
            postgres)
                DATA_REL_DOCKERFILE="docker/data-rel/Dockerfile-data-postgres"
                ;;
            mysql)
                DATA_REL_DOCKERFILE="docker/data-rel/Dockerfile-data-mysql"
                ;;
            mariadb)
                DATA_REL_DOCKERFILE="docker/data-rel/Dockerfile-data-mariadb"
                ;;
            *)
                echo "Error: Unsupported DATA_REL_TYPE '$DATA_REL_TYPE'. Must be postgres, mysql, or mariadb."
                exit 1
                ;;
        esac
        echo "Auto-selected Dockerfile: $DATA_REL_DOCKERFILE"
    else
        echo "Using DATA_REL_DOCKERFILE from .env: $DATA_REL_DOCKERFILE"
    fi

    # Authenticate via AWS SSO for data (only if profile is set)
    if [[ -n "$DATA_REL_AWS_CLI_PROFILE" ]]; then
        echo "Authenticating via AWS SSO for data..."
        aws sso login --profile $DATA_REL_AWS_CLI_PROFILE --no-browser
        if [ $? -eq 0 ]; then
            echo "AWS SSO authentication for data successful."
        else
            echo "AWS SSO authentication for data failed."
            echo "If you see 'Cannot perform an interactive login from a non TTY device', run 'aws sso login --profile $DATA_REL_AWS_CLI_PROFILE' manually in your terminal before running this script."
            exit 1
        fi

        # Authenticate Docker to AWS ECR
        echo "Authenticating Docker to AWS ECR for data..."
        aws ecr get-login-password --region $DATA_REL_AWS_REGION --profile $DATA_REL_AWS_CLI_PROFILE | docker login --username AWS --password-stdin $DATA_REL_AWS_ACCOUNT_ID.dkr.ecr.$DATA_REL_AWS_REGION.amazonaws.com
        if [ $? -eq 0 ]; then
            echo "Docker authenticated to AWS ECR for data successfully."
        else
            echo "Docker authentication to AWS ECR for data failed."
            echo "If you see an SSL certificate error, ensure your system CA certificates are up to date. On Windows, update your system certificates and ensure you have the latest AWS CLI and Python installed."
            exit 1
        fi
    else
        echo "DATA_REL_AWS_CLI_PROFILE not set, skipping AWS SSO authentication for data."
    fi

    # Pull or build the data image
    if [[ -z "$DATA_REL_AWS_ACCOUNT_ID" || -z "$DATA_REL_AWS_REGION" || -z "$DATA_REL_REPO_NAME" || -z "$DATA_REL_IMAGE_TAG" ]]; then
        echo "Remote data image details not set. Building Docker data image using Dockerfile: $DATA_REL_DOCKERFILE..."
        DATA_REL_BUILD_ARGS=""
        if [[ -n "$DATA_REL_BASE_IMAGE" ]]; then
            DATA_REL_BUILD_ARGS="--build-arg BASE_IMAGE=$DATA_REL_BASE_IMAGE"
            echo "Using custom data base image: $DATA_REL_BASE_IMAGE"
        fi
        DATA_REL_BUILD_ARGS="$DATA_REL_BUILD_ARGS --build-arg DATA_REL_DB=$DATA_REL_NAME --build-arg DATA_REL_USER=$DATA_REL_USERNAME --build-arg DATA_REL_PASSWORD=$DATA_REL_PASSWORD --build-arg DATA_REL_PORT_HOST=$DATA_REL_HOST_PORT --build-arg DATA_REL_PORT_CONTAINER=$DATA_REL_CONTAINER_PORT"
        docker build -f "$DATA_REL_DOCKERFILE" $DATA_REL_BUILD_ARGS -t local-build-data-image .
        if [ $? -eq 0 ]; then
            echo "Docker data image built successfully from Dockerfile."
            DATA_REL_IMAGE_TO_RUN="local-build-data-image"
        else
            echo "Failed to build Docker data image from Dockerfile."; exit 1
        fi
    else
        echo "Pulling Docker data image..."
        docker pull $DATA_REL_AWS_ACCOUNT_ID.dkr.ecr.$DATA_REL_AWS_REGION.amazonaws.com/$DATA_REL_REPO_NAME:$DATA_REL_IMAGE_TAG
        if [ $? -eq 0 ]; then
            echo "Docker data image pulled successfully."
            DATA_REL_IMAGE_TO_RUN="$DATA_REL_AWS_ACCOUNT_ID.dkr.ecr.$DATA_REL_AWS_REGION.amazonaws.com/$DATA_REL_REPO_NAME:$DATA_REL_IMAGE_TAG"
        else
            echo "Failed to pull Docker data image."; exit 1
        fi
    fi

    # Build data docker run options
    echo "Building data docker run options..."
    DATA_REL_DOCKER_RUN_OPTS="-d -p $DATA_REL_HOST_PORT:$DATA_REL_CONTAINER_PORT --network $NETWORK_NAME"
    if [[ -n "$DATA_REL_HOST_VOLUME_PATH" && -n "$DATA_REL_CONTAINER_VOLUME_PATH" ]]; then
        DATA_REL_DOCKER_RUN_OPTS="$DATA_REL_DOCKER_RUN_OPTS -v $DATA_REL_HOST_VOLUME_PATH:$DATA_REL_CONTAINER_VOLUME_PATH"
        echo "Volume mapping for data enabled: $DATA_REL_HOST_VOLUME_PATH -> $DATA_REL_CONTAINER_VOLUME_PATH"
    else
        echo "No volume mapping for data configured."
    fi

    # Run the data container with set run options
    echo "Running Docker data container (type: $DATA_REL_TYPE)..."
    
    # Set database-specific environment variables
    case "$DATA_REL_TYPE" in
        postgres)
            DB_ENV_VARS="-e POSTGRES_PASSWORD=$DATA_REL_PASSWORD -e POSTGRES_DB=$DATA_REL_NAME -e POSTGRES_USER=$DATA_REL_USERNAME"
            ;;
        mysql)
            DB_ENV_VARS="-e MYSQL_ROOT_PASSWORD=$DATA_REL_PASSWORD -e MYSQL_DATABASE=$DATA_REL_NAME -e MYSQL_USER=$DATA_REL_USERNAME -e MYSQL_PASSWORD=$DATA_REL_PASSWORD"
            ;;
        mariadb)
            DB_ENV_VARS="-e MARIADB_ROOT_PASSWORD=$DATA_REL_PASSWORD -e MARIADB_DATABASE=$DATA_REL_NAME -e MARIADB_USER=$DATA_REL_USERNAME -e MARIADB_PASSWORD=$DATA_REL_PASSWORD"
            ;;
    esac
    
    DATA_REL_CONTAINER_ID=$(docker run $DATA_REL_DOCKER_RUN_OPTS \
        --name "$DATA_REL_CONTAINER_NAME" \
        $DB_ENV_VARS \
        -e DATA_REL_PORT_HOST="$DATA_REL_HOST_PORT" \
        -e DATA_REL_PORT_CONTAINER="$DATA_REL_CONTAINER_PORT" \
        $DATA_REL_IMAGE_TO_RUN)
    if [ $? -eq 0 ]; then
        echo "Docker data container started successfully."
        echo "Data Container ID: $DATA_REL_CONTAINER_ID"
        docker inspect "$DATA_REL_CONTAINER_ID"
        DATA_REL_CONTAINER_SUMMARY="Data Container:\n  Name: $DATA_REL_CONTAINER_NAME\n  Address: localhost:$DATA_REL_HOST_PORT\n  ID: $DATA_REL_CONTAINER_ID"
    else
        echo "Failed to start Docker data container."
        exit 1
    fi
fi

#####################
# DATA-NONREL CONTAINER #
#####################

DATA_NONREL_CONTAINER_NAME="$PROJECT_NAME-data-nonrel-container"
REBUILD_OR_NEW_DATA_NONREL=0
DATA_NONREL_CONTAINER_SUMMARY=""
if container_exists "$DATA_NONREL_CONTAINER_NAME"; then
    echo "Container $DATA_NONREL_CONTAINER_NAME already exists. Checking status..."
    STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_NONREL_CONTAINER_NAME" 2>/dev/null)
    if [[ "$STATUS" == "running" ]]; then
        echo "Container $DATA_NONREL_CONTAINER_NAME is already running."
        DATA_NONREL_CONTAINER_ID=$(docker inspect -f '{{.Id}}' "$DATA_NONREL_CONTAINER_NAME" 2>/dev/null)
        DATA_NONREL_CONTAINER_SUMMARY="Data-NonRel Container:\n  Name: $DATA_NONREL_CONTAINER_NAME\n  Address: localhost:$DATA_NONREL_HOST_PORT\n  ID: $DATA_NONREL_CONTAINER_ID"
    else
        echo "Container $DATA_NONREL_CONTAINER_NAME exists but is not running. Starting..."
        docker start "$DATA_NONREL_CONTAINER_NAME"
        STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_NONREL_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" == "running" ]]; then
            echo "Container $DATA_NONREL_CONTAINER_NAME started."
            DATA_NONREL_CONTAINER_ID=$(docker inspect -f '{{.Id}}' "$DATA_NONREL_CONTAINER_NAME" 2>/dev/null)
            DATA_NONREL_CONTAINER_SUMMARY="Data-NonRel Container:\n  Name: $DATA_NONREL_CONTAINER_NAME\n  Address: localhost:$DATA_NONREL_HOST_PORT\n  ID: $DATA_NONREL_CONTAINER_ID"
        else
            echo "Failed to start $DATA_NONREL_CONTAINER_NAME."
            exit 1
        fi
    fi
    if [[ "$REBUILD_DATA_CONTAINER" == "1" ]]; then
        echo "Rebuilding data-nonrel container..."
        STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_NONREL_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" == "running" ]]; then
            docker stop "$DATA_NONREL_CONTAINER_NAME"
        fi
        docker rm -v "$DATA_NONREL_CONTAINER_NAME"
        REBUILD_OR_NEW_DATA_NONREL=1
    fi
else
    # Only build if DATA_NONREL_TYPE is set
    if [[ -n "$DATA_NONREL_TYPE" ]]; then
        REBUILD_OR_NEW_DATA_NONREL=1
    fi
fi
if [[ "$REBUILD_OR_NEW_DATA_NONREL" == "1" ]]; then
    echo "Using DATA_NONREL_TYPE from .env: $DATA_NONREL_TYPE"

    # Auto-select Dockerfile based on database type if not explicitly set
    if [[ -z "$DATA_NONREL_DOCKERFILE" ]]; then
        case "$DATA_NONREL_TYPE" in
            mongodb)
                DATA_NONREL_DOCKERFILE="docker/data-nonrel/Dockerfile-data-mongodb"
                ;;
            neo4j)
                DATA_NONREL_DOCKERFILE="docker/data-nonrel/Dockerfile-data-neo4j"
                ;;
            *)
                echo "Error: Unsupported DATA_NONREL_TYPE '$DATA_NONREL_TYPE'. Must be mongodb or neo4j."
                exit 1
                ;;
        esac
        echo "Auto-selected Dockerfile: $DATA_NONREL_DOCKERFILE"
    else
        echo "Using DATA_NONREL_DOCKERFILE from .env: $DATA_NONREL_DOCKERFILE"
    fi

    # Authenticate via AWS SSO for data-nonrel (only if profile is set)
    if [[ -n "$DATA_NONREL_AWS_CLI_PROFILE" ]]; then
        echo "Authenticating via AWS SSO for data-nonrel..."
        aws sso login --profile $DATA_NONREL_AWS_CLI_PROFILE --no-browser
        if [ $? -eq 0 ]; then
            echo "AWS SSO authentication for data-nonrel successful."
        else
            echo "AWS SSO authentication for data-nonrel failed."
            echo "If you see 'Cannot perform an interactive login from a non TTY device', run 'aws sso login --profile $DATA_NONREL_AWS_CLI_PROFILE' manually in your terminal before running this script."
            exit 1
        fi

        # Authenticate Docker to AWS ECR
        echo "Authenticating Docker to AWS ECR for data-nonrel..."
        aws ecr get-login-password --region $DATA_NONREL_AWS_REGION --profile $DATA_NONREL_AWS_CLI_PROFILE | docker login --username AWS --password-stdin $DATA_NONREL_AWS_ACCOUNT_ID.dkr.ecr.$DATA_NONREL_AWS_REGION.amazonaws.com
        if [ $? -eq 0 ]; then
            echo "Docker authenticated to AWS ECR for data-nonrel successfully."
        else
            echo "Docker authentication to AWS ECR for data-nonrel failed."
            echo "If you see an SSL certificate error, ensure your system CA certificates are up to date. On Windows, update your system certificates and ensure you have the latest AWS CLI and Python installed."
            exit 1
        fi
    else
        echo "DATA_NONREL_AWS_CLI_PROFILE not set, skipping AWS SSO authentication for data-nonrel."
    fi

    # Pull or build the data-nonrel image
    if [[ -z "$DATA_NONREL_AWS_ACCOUNT_ID" || -z "$DATA_NONREL_AWS_REGION" || -z "$DATA_NONREL_REPO_NAME" || -z "$DATA_NONREL_IMAGE_TAG" ]]; then
        echo "Remote data-nonrel image details not set. Building Docker data-nonrel image using Dockerfile: $DATA_NONREL_DOCKERFILE..."
        DATA_NONREL_BUILD_ARGS=""
        if [[ -n "$DATA_NONREL_BASE_IMAGE" ]]; then
            DATA_NONREL_BUILD_ARGS="--build-arg BASE_IMAGE=$DATA_NONREL_BASE_IMAGE"
            echo "Using custom data-nonrel base image: $DATA_NONREL_BASE_IMAGE"
        fi
        DATA_NONREL_BUILD_ARGS="$DATA_NONREL_BUILD_ARGS --build-arg DATA_NONREL_DB=$DATA_NONREL_NAME --build-arg DATA_NONREL_USER=$DATA_NONREL_USERNAME --build-arg DATA_NONREL_PASSWORD=$DATA_NONREL_PASSWORD --build-arg DATA_NONREL_PORT_HOST=$DATA_NONREL_HOST_PORT --build-arg DATA_NONREL_PORT_CONTAINER=$DATA_NONREL_CONTAINER_PORT"
        docker build -f "$DATA_NONREL_DOCKERFILE" $DATA_NONREL_BUILD_ARGS -t local-build-data-nonrel-image .
        if [ $? -eq 0 ]; then
            echo "Docker data-nonrel image built successfully from Dockerfile."
            DATA_NONREL_IMAGE_TO_RUN="local-build-data-nonrel-image"
        else
            echo "Failed to build Docker data-nonrel image from Dockerfile."; exit 1
        fi
    else
        echo "Pulling Docker data-nonrel image..."
        docker pull $DATA_NONREL_AWS_ACCOUNT_ID.dkr.ecr.$DATA_NONREL_AWS_REGION.amazonaws.com/$DATA_NONREL_REPO_NAME:$DATA_NONREL_IMAGE_TAG
        if [ $? -eq 0 ]; then
            echo "Docker data-nonrel image pulled successfully."
            DATA_NONREL_IMAGE_TO_RUN="$DATA_NONREL_AWS_ACCOUNT_ID.dkr.ecr.$DATA_NONREL_AWS_REGION.amazonaws.com/$DATA_NONREL_REPO_NAME:$DATA_NONREL_IMAGE_TAG"
        else
            echo "Failed to pull Docker data-nonrel image."; exit 1
        fi
    fi

    # Build data-nonrel docker run options
    echo "Building data-nonrel docker run options..."
    DATA_NONREL_DOCKER_RUN_OPTS="-d -p $DATA_NONREL_HOST_PORT:$DATA_NONREL_CONTAINER_PORT --network $NETWORK_NAME"
    if [[ -n "$DATA_NONREL_HOST_VOLUME_PATH" && -n "$DATA_NONREL_CONTAINER_VOLUME_PATH" ]]; then
        DATA_NONREL_DOCKER_RUN_OPTS="$DATA_NONREL_DOCKER_RUN_OPTS -v $DATA_NONREL_HOST_VOLUME_PATH:$DATA_NONREL_CONTAINER_VOLUME_PATH"
        echo "Volume mapping for data-nonrel enabled: $DATA_NONREL_HOST_VOLUME_PATH -> $DATA_NONREL_CONTAINER_VOLUME_PATH"
    else
        echo "No volume mapping for data-nonrel configured."
    fi

    # Run the data-nonrel container with set run options
    echo "Running Docker data-nonrel container (type: $DATA_NONREL_TYPE)..."
    
    # Set database-specific environment variables
    case "$DATA_NONREL_TYPE" in
        mongodb)
            DB_NONREL_ENV_VARS="-e MONGO_INITDB_ROOT_USERNAME=$DATA_NONREL_USERNAME -e MONGO_INITDB_ROOT_PASSWORD=$DATA_NONREL_PASSWORD -e MONGO_INITDB_DATABASE=$DATA_NONREL_NAME"
            ;;
        neo4j)
            DB_NONREL_ENV_VARS="-e NEO4J_AUTH=$DATA_NONREL_USERNAME/$DATA_NONREL_PASSWORD -e NEO4J_dbms_default__database=$DATA_NONREL_NAME"
            ;;
    esac
    
    DATA_NONREL_CONTAINER_ID=$(docker run $DATA_NONREL_DOCKER_RUN_OPTS \
        --name "$DATA_NONREL_CONTAINER_NAME" \
        $DB_NONREL_ENV_VARS \
        -e DATA_NONREL_PORT_HOST="$DATA_NONREL_HOST_PORT" \
        -e DATA_NONREL_PORT_CONTAINER="$DATA_NONREL_CONTAINER_PORT" \
        $DATA_NONREL_IMAGE_TO_RUN)
    if [ $? -eq 0 ]; then
        echo "Docker data-nonrel container started successfully."
        echo "Data-NonRel Container ID: $DATA_NONREL_CONTAINER_ID"
        docker inspect "$DATA_NONREL_CONTAINER_ID"
        DATA_NONREL_CONTAINER_SUMMARY="Data-NonRel Container:\n  Name: $DATA_NONREL_CONTAINER_NAME\n  Address: localhost:$DATA_NONREL_HOST_PORT\n  ID: $DATA_NONREL_CONTAINER_ID"
    else
        echo "Failed to start Docker data-nonrel container."
        exit 1
    fi
fi

# Import DATA_REL_SOURCEFILE into database if set and --import-data flag is set
if [[ "$IMPORT_DATA" == "1" && -n "$DATA_REL_SOURCEFILE" ]]; then
    echo "Importing $DATA_REL_SOURCEFILE into $DATA_REL_TYPE database..."
    BASENAME=$(basename "$DATA_REL_SOURCEFILE")
    # Ensure container is running before waiting for database
    STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
    if [[ "$STATUS" != "running" ]]; then
        echo "Container $DATA_REL_CONTAINER_NAME is not running. Starting..."
        docker start "$DATA_REL_CONTAINER_NAME"
        STATUS=$(docker inspect -f '{{.State.Status}}' "$DATA_REL_CONTAINER_NAME" 2>/dev/null)
        if [[ "$STATUS" != "running" ]]; then
            echo "Could not start data container name $DATA_REL_CONTAINER_NAME. Not attempting data import."
            exit 1
        fi
    fi
    
    # Wait for database to be ready
    echo "Waiting for $DATA_REL_TYPE to be ready..."
    case "$DATA_REL_TYPE" in
        postgres)
            for i in {1..30}; do
                docker exec $DATA_REL_CONTAINER_NAME pg_isready -U "$DATA_REL_USERNAME" && break
                sleep 2
            done
            ;;
        mysql|mariadb)
            for i in {1..30}; do
                docker exec $DATA_REL_CONTAINER_NAME mysqladmin ping -h localhost -u "$DATA_REL_USERNAME" -p"$DATA_REL_PASSWORD" 2>/dev/null && break
                sleep 2
            done
            ;;
    esac
    
    # Import based on file type and database type
    if [[ "$BASENAME" == *.zip ]]; then
        echo "Detected compressed file (.zip). Unzipping $DATA_REL_SOURCEFILE and importing into $DATA_REL_NAME..."
        case "$DATA_REL_TYPE" in
            postgres)
                unzip -p "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" psql -q -U "$DATA_REL_USERNAME" -d "$DATA_REL_NAME"
                ;;
            mysql|mariadb)
                unzip -p "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" mysql -u "$DATA_REL_USERNAME" -p"$DATA_REL_PASSWORD" "$DATA_REL_NAME"
                ;;
        esac
    elif [[ "$BASENAME" == *.gz ]]; then
        echo "Detected compressed file (.gz). Decompressing $DATA_REL_SOURCEFILE and importing into $DATA_REL_NAME..."
        case "$DATA_REL_TYPE" in
            postgres)
                gunzip -c "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" psql -q -U "$DATA_REL_USERNAME" -d "$DATA_REL_NAME"
                ;;
            mysql|mariadb)
                gunzip -c "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" mysql -u "$DATA_REL_USERNAME" -p"$DATA_REL_PASSWORD" "$DATA_REL_NAME"
                ;;
        esac
    elif [[ "$BASENAME" == *.sql ]]; then
        echo "Detected .sql file. Importing $DATA_REL_SOURCEFILE into $DATA_REL_NAME..."
        case "$DATA_REL_TYPE" in
            postgres)
                cat "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" psql -q -U "$DATA_REL_USERNAME" -d "$DATA_REL_NAME"
                ;;
            mysql|mariadb)
                cat "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" mysql -u "$DATA_REL_USERNAME" -p"$DATA_REL_PASSWORD" "$DATA_REL_NAME"
                ;;
        esac
    elif [[ "$BASENAME" == *.dump || "$BASENAME" == *.backup || "$BASENAME" == *.tar ]]; then
        case "$DATA_REL_TYPE" in
            postgres)
                echo "Detected custom/tar format. Importing $DATA_REL_SOURCEFILE into $DATA_REL_NAME using pg_restore..."
                cat "$DATA_REL_SOURCEFILE" | docker exec -i "$DATA_REL_CONTAINER_NAME" pg_restore -q -U "$DATA_REL_USERNAME" -d "$DATA_REL_NAME"
                ;;
            mysql|mariadb)
                echo "Detected dump/backup format. For MySQL/MariaDB, please use .sql format instead."
                exit 1
                ;;
        esac
    else
        echo "Incompatible data source format. Must be of type .zip, .gz, .sql, .dump, .backup, or .tar."
    fi
    if [ $? -eq 0 ]; then
        echo "Data import completed successfully."
    else
        echo "Data import failed."
        exit 1
    fi
fi

# Print container summary at the end
cat <<EOM

============================
  Container Startup Summary
============================
$(if [[ -n "$APP_CONTAINER_SUMMARY" ]]; then echo -e "$APP_CONTAINER_SUMMARY"; fi)
$(if [[ -n "$DATA_REL_CONTAINER_SUMMARY" ]]; then echo -e "$DATA_REL_CONTAINER_SUMMARY"; fi)
$(if [[ -n "$DATA_NONREL_CONTAINER_SUMMARY" ]]; then echo -e "$DATA_NONREL_CONTAINER_SUMMARY"; fi)
$(if [[ -z "$APP_CONTAINER_SUMMARY" && -z "$DATA_REL_CONTAINER_SUMMARY" && -z "$DATA_NONREL_CONTAINER_SUMMARY" ]]; then echo "No containers were started."; fi)
============================

EOM
