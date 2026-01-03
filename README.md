# Docker App Build Kit

A comprehensive Docker container build and management toolkit for multi-stack application development. Supports PHP, Node.js, Python, Java applications with PostgreSQL, MySQL, MariaDB, MongoDB, and Neo4j databases.

Available in **three implementations**: PHP, Python, and Node.js - choose the one that best fits your workflow!

## Installation

### PHP Version (via Composer)

```bash
composer require dsdobrzynski/dapp-bk
```

**Usage:**
```bash
# Global install
composer global require dsdobrzynski/dapp-bk
dapp-bk build

# Project install
vendor/bin/dapp-bk build
```

### Python Version (via pip)

```bash
pip install dapp-bk
```

**Usage:**
```bash
dapp-bk-py build
dapp-bk-py composer:install
dapp-bk-py network:fix
```

### Node.js Version (via npm)

```bash
npm install -g @dsdobrzynski/dapp-bk
```

**Usage:**
```bash
dapp-bk-node build
dapp-bk-node composer:install
dapp-bk-node network:fix
```

### From Source

```bash
git clone https://github.com/dsdobrzynski/dapp-bk
cd dapp-bk

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

1. **Install the package** (choose your preferred method from Installation above)

2. **Copy the `.env.example` file to your project root**:

When installed via Composer:
```bash
cp vendor/dsdobrzynski/dapp-bk/.env.example .env
```

When installed via pip:
```bash
# Find the package location
pip show dapp-bk | grep Location
# Then copy from that location, or download from GitHub
curl -o .env https://raw.githubusercontent.com/dsdobrzynski/dapp-bk/main/.env.example
```

When installed via npm:
```bash
cp node_modules/@dsdobrzynski/dapp-bk/.env.example .env
```

**Your project structure should look like:**
```
your-project/
├── .env                    # Your configuration (in project root)
├── composer.json           # (if using PHP)
├── package.json            # (if using Node.js)
├── docker/                 # Optional: custom Dockerfiles
│   ├── app/
│   └── data-rel/
├── src/                    # Your application code
└── vendor/                 # (if using PHP)
    └── dsdobrzynski/
        └── dapp-bk/        # Installed package
```

3. **Configure your environment**:
```bash
# Edit .env with your project-specific settings
nano .env  # or your preferred editor
```

**Required settings:**
- `PROJECT_NAME` - Your project identifier
- `APP_TYPE` - Application type (php-apache, node, python, java)
- `APP_HOST_PORT` - Port for accessing your app (e.g., 8080)
- `APP_HOST_VOLUME_PATH` - Path to your source code (e.g., "./src")
- `DATA_REL_TYPE` - Database type (postgres, mysql, mariadb)

4. **Build and start containers**:

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

Create `.env` from `.env.example`:

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
APP_DOCKERFILE=docker/app/Dockerfile-app-custom
DATA_REL_DOCKERFILE=docker/data-rel/Dockerfile-data-custom
```

### Volume Mounts (Bind Mount Approach)

Mount your local source code directory into the container for live development. This is the recommended approach for local development as changes to your code are immediately reflected in the running container without requiring a rebuild.

**Configuration in `.env`:**

```env
# Map local source code to container webroot
APP_HOST_VOLUME_PATH="/absolute/path/to/your/sourcecode"
APP_CONTAINER_VOLUME_PATH="/var/www/html"
```

**Platform-Specific Examples:**

**Windows:**
```env
APP_HOST_VOLUME_PATH="C:/Users/yourname/projects/myapp/src"
APP_CONTAINER_VOLUME_PATH="/var/www/html"
```

**Linux/Mac:**
```env
APP_HOST_VOLUME_PATH="/home/yourname/projects/myapp/src"
APP_CONTAINER_VOLUME_PATH="/var/www/html"
```

**Relative Path (from project root):**
```env
APP_HOST_VOLUME_PATH="./src"
APP_CONTAINER_VOLUME_PATH="/var/www/html"
```

**How It Works:**
- The toolkit uses Docker's `-v` flag to create a bind mount
- Your local files at `APP_HOST_VOLUME_PATH` are mapped directly to `APP_CONTAINER_VOLUME_PATH` in the container
- Any changes you make on your host system are immediately visible inside the container
- Perfect for development workflow - no rebuild needed after code changes

**For Database Containers:**
```env
# PostgreSQL example
DATA_REL_HOST_VOLUME_PATH="/path/to/postgres/data"
DATA_REL_CONTAINER_VOLUME_PATH="/var/lib/postgresql/data"
```

**Note:** If volume paths are not set or left empty, no volume mapping will be configured and the container will use its internal filesystem only.

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
bash app/scripts/docker-build.sh --rebuild-app --import-data
bash app/scripts/app-build.sh
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
- GitHub Issues: https://github.com/dsdobrzynski/dapp-bk/issues
- Documentation: https://github.com/dsdobrzynski/dapp-bk#readme
