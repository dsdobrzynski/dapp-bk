# Docker App Build Kit

A comprehensive Docker container build and management toolkit for multi-stack application development. Supports PHP, Node.js, Python, Java applications with PostgreSQL, MySQL, MariaDB, MongoDB, and Neo4j databases.

Available in **three implementations**: PHP, Python, and Node.js - choose the one that best fits your workflow!

## Installation

### PHP Version (via Composer)

```bash
composer require dsdobrzynski/docker-app-build-kit
```

**Usage:**
```bash
# Global install
composer global require dsdobrzynski/docker-app-build-kit
dapp-bk build

# Project install
vendor/bin/dapp-bk build
```

### Python Version (via pip)

```bash
pip install docker-app-build-kit
```

**Usage:**
```bash
dapp-bk-py build
dapp-bk-py composer:install
dapp-bk-py network:fix
```

### Node.js Version (via npm)

```bash
npm install -g @dsdobrzynski/docker-app-build-kit
```

**Usage:**
```bash
dapp-bk-node build
dapp-bk-node composer:install
dapp-bk-node network:fix
```

### From Source

```bash
git clone https://github.com/dsdobrzynski/docker-app-build-kit
cd docker-app-build-kit

# For PHP
composer install
php bin/dapp-bk build

# For Python
pip install -e .
dapp-bk-py build

# For Node.js
npm install
node nodejs/bin/dapp-bk-node.js build
```

## Quick Start

1. **Create your project structure with a `build/` directory**:
```
your-project/
├── build/
│   ├── .env
│   └── .env.example
├── src/
└── ...
```

2. **Configure your environment**:
```bash
cp build/.env.example build/.env
# Edit build/.env with your settings
```

3. **Build and start containers**:

**PHP:**
```bash
dapp-bk build
# or: php vendor/bin/dapp-bk build
```

**Python:**
```bash
dapp-bk-py build
```

**Node.js:**
```bash
dapp-bk-node build
```

## Commands

All three implementations (PHP, Python, Node.js) support the same commands:

### `build` - Build and manage Docker containers

Build and start application and database containers based on your `.env` configuration.

```bash
# PHP
dapp-bk build [options]

# Python
dapp-bk-py build [options]

# Node.js
dapp-bk-node build [options]
```

**Options:**
- `--rebuild-app` - Force rebuild of application container
- `--rebuild-data` - Force rebuild of database containers
- `--import-data` - Import data into database containers

**Examples:**
```bash
# Normal build (reuses existing containers) - PHP version
dapp-bk build

# Rebuild app container - Python version
dapp-bk-py build --rebuild-app

# Rebuild everything and import data - Node.js version
dapp-bk-node build --rebuild-app --rebuild-data --import-data
```

### `composer:install` - Install PHP dependencies

Install Composer dependencies in the running application container.

```bash
# PHP
dapp-bk composer:install

# Python
dapp-bk-py composer:install

# Node.js
dapp-bk-node composer:install
```

This command:
- Detects your running app container
- Installs Composer if not present
- Runs `composer install` inside the container

### `network:fix` - Fix Docker network issues

Fix common Docker network connectivity problems.

```bash
# PHP
dapp-bk network:fix

# Python
dapp-bk-py network:fix

# Node.js
dapp-bk-node network:fix
```

This command handles platform-specific network issues on Windows and Linux.

## Environment Configuration

### Required Variables

Create `build/.env` from `build/.env.example`:

```env
# Project Configuration
PROJECT_NAME=my-project

# Application Type (php-apache, node, python, java)
APP_TYPE=php-apache
APP_HOST_PORT=8080

# Relational Database (postgres, mysql, mariadb)
DATA_REL_TYPE=postgres
DATA_REL_HOST_PORT=5432

# Non-Relational Database (mongodb, neo4j, or leave empty)
DATA_NONREL_TYPE=
DATA_NONREL_HOST_PORT=

# Volume Mounts
APP_VOLUME_HOST=./src
APP_VOLUME_CONTAINER=/var/www/html

# AWS ECR (if using private images)
APP_AWS_CLI_PROFILE=
APP_AWS_REGION=
APP_AWS_ACCOUNT_ID=
APP_REPO_NAME=
APP_IMAGE_TAG=
```

### Supported Application Types

- `php-apache` - PHP with Apache web server (default)
- `node` - Node.js applications
- `python` - Python (Flask/Django)
- `java` - Java (Spring Boot)

### Supported Databases

**Relational:**
- `postgres` - PostgreSQL (default)
- `mysql` - MySQL
- `mariadb` - MariaDB

**Non-Relational:**
- `mongodb` - MongoDB
- `neo4j` - Neo4j graph database

## Docker Organization

The toolkit includes pre-configured Dockerfiles:

```
docker/
├── app/
│   ├── Dockerfile-app-php
│   ├── Dockerfile-app-node
│   ├── Dockerfile-app-python
│   └── Dockerfile-app-java
├── data-rel/
│   ├── Dockerfile-data-postgres
│   ├── Dockerfile-data-mysql
│   └── Dockerfile-data-mariadb
└── data-nonrel/
    ├── Dockerfile-data-mongodb
    └── Dockerfile-data-neo4j
```

## Advanced Usage

### Custom Dockerfiles

Override default Dockerfiles in your `.env`:

```env
APP_DOCKERFILE=build/docker/app/Dockerfile-app-custom
DATA_REL_DOCKERFILE=build/docker/data-rel/Dockerfile-data-custom
```

### Volume Mounts

Mount your source code into the container:

```env
APP_VOLUME_HOST=./src
APP_VOLUME_CONTAINER=/var/www/html
```

### AWS ECR Integration

For private Docker images from AWS ECR:

```env
APP_AWS_CLI_PROFILE=my-profile
APP_AWS_REGION=us-east-1
APP_AWS_ACCOUNT_ID=123456789012
APP_REPO_NAME=my-app-repo
APP_IMAGE_TAG=latest
```

The toolkit will automatically authenticate with AWS SSO and ECR.

## Migrating from Bash Scripts

If you're currently using the bash scripts (`scripts/docker-build.sh`, `scripts/app-build.sh`):

**Before:**
```bash
bash build/scripts/docker-build.sh --rebuild-app --import-data
bash build/scripts/app-build.sh
```

**After (choose your preferred language):**

PHP:
```bash
dapp-bk build --rebuild-app --import-data
dapp-bk composer:install
```

Python:
```bash
dapp-bk-py build --rebuild-app --import-data
dapp-bk-py composer:install
```

Node.js:
```bash
dapp-bk-node build --rebuild-app --import-data
dapp-bk-node composer:install
```

## Requirements

### For PHP Version
- PHP >= 7.4
- Composer
- Docker Desktop

### For Python Version
- Python >= 3.7
- pip
- Docker Desktop

### For Node.js Version
- Node.js >= 16.0.0
- npm
- Docker Desktop

### All Versions
- Git
- Docker Desktop (Linux or Windows with WSL2)

## Development

### Running Tests
```bash
composer test
```

### Code Style
```bash
composer cs-fix
```

## License

MIT License

## Contributing

Contributions are welcome! Please submit pull requests or open issues on GitHub.

## Support

For issues and questions:
- GitHub Issues: https://github.com/dsdobrzynski/docker-app-build-kit/issues
- Documentation: https://github.com/dsdobrzynski/docker-app-build-kit#readme
