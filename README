# Local Development Setup & Usage

This guide explains how to set up and use the local build and container management scripts for the RTQI ImageBuilder Pipeline project.

## Overview
The local development environment allows you to build, test, and debug the RTQI application locally before deploying through the ImageBuilder pipeline. This includes both the application container and data container for complete local development.

The build directory is organized into two main subdirectories:
- **`scripts/`** - Executable build and automation scripts
- **`docker/`** - Container definitions and Dockerfiles

## Prerequisites
- Docker Desktop (Linux or Windows with WSL2)
- Git Bash (Windows) or any bash shell
- AWS CLI (configured for SSO/ECR access)
- PowerShell (Windows) - for running bash scripts from PowerShell environment

## Scripts Organization

The build directory is organized with a dedicated `scripts/` subdirectory for better organization and maintainability:

```
build/
├── scripts/
│   ├── docker-build.sh     # Main container management script
│   └── app-build.sh        # Composer dependency installation
├── docker/
│   ├── app/
│   │   ├── Dockerfile-app-php   # PHP/Apache container
│   │   ├── Dockerfile-app-node         # Node.js container
│   │   ├── Dockerfile-app-python       # Python container
│   │   └── Dockerfile-app-java         # Java container
│   ├── data-rel/
│   │   ├── Dockerfile-data-postgres     # PostgreSQL container
│   │   ├── Dockerfile-data-mysql        # MySQL container
│   │   └── Dockerfile-data-mariadb      # MariaDB container
│   ├── data-nonrel/
│   │   ├── Dockerfile-data-mongodb      # MongoDB container
│   │   └── Dockerfile-data-neo4j        # Neo4j container
├── .env                    # Environment configuration
├── .env.example           # Environment template
└── README                 # This documentation
```

### Script Descriptions

**docker-build.sh** - Primary build script for container management:
- Builds and manages application and data containers
- Handles AWS ECR authentication and image pulling/building
- Supports database import functionality
- Creates Docker networks and manages container lifecycle
- Uses application Dockerfiles in `build/docker/app/`, relational database Dockerfiles in `build/docker/data-rel/`, and non-relational database Dockerfiles in `build/docker/data-nonrel/` by default

**app-build.sh** - Composer dependency management:
- Installs PHP dependencies using Composer
- Automatically detects container and project structure
- Handles Composer installation if not present
- Optimized for production deployments

### Docker Organization

Container definitions are organized in the `docker/` subdirectory:
- **`app/`** - Application containers
  - **`Dockerfile-app-php`** - PHP application container with Apache web server
  - **`Dockerfile-app-node`** - Node.js application container
  - **`Dockerfile-app-python`** - Python application container (Flask/Django)
  - **`Dockerfile-app-java`** - Java application container (Spring Boot)
- **`data-rel/`** - Relational database containers
  - **`Dockerfile-data-postgres`** - PostgreSQL database container with custom configuration
  - **`Dockerfile-data-mysql`** - MySQL database container with custom configuration
  - **`Dockerfile-data-mariadb`** - MariaDB database container with custom configuration
- **`data-nonrel/`** - Non-relational database containers
  - **`Dockerfile-data-mongodb`** - MongoDB database container with custom configuration
  - **`Dockerfile-data-neo4j`** - Neo4j graph database container with custom configuration

## Environment Configuration

### Initial Setup
1. Copy `build/.env.example` to `build/.env` and fill in all required values.
2. Set project name, AWS credentials, port mappings, and volume paths in `.env`.
3. Ensure Dockerfiles (application files in `build/docker/app/`, relational database files in `build/docker/data-rel/`, and non-relational database files in `build/docker/data-nonrel/`) are present and correct for your environment.

### Environment Variables
Key variables to configure in `.env`:
- `PROJECT_NAME` - Your project identifier
- `APP_TYPE` - Application type: `php-apache`, `node`, `python`, or `java` (default: php-apache)
- `DATA_REL_TYPE` - Relational database type: `postgres`, `mysql`, or `mariadb` (default: postgres)
- `DATA_NONREL_TYPE` - Non-relational database type: `mongodb` or `neo4j` (leave empty to skip)
- `APP_HOST_PORT` - Port for application container (default: 8080)
- `DATA_REL_HOST_PORT` - Port for relational data container (default: 5432 for postgres, 3306 for mysql/mariadb)
- `DATA_NONREL_HOST_PORT` - Port for non-relational data container (default: 27017 for mongodb, 7687 for neo4j)7687 for neo4j)
- `APP_DOCKERFILE` - Path to application Dockerfile (auto-selected based on APP_TYPE if not set)
- `DATA_REL_DOCKERFILE` - Path to relational data Dockerfile (auto-selected based on DATA_REL_TYPE if not set)
- `DATA_NONREL_DOCKERFILE` - Path to non-relational data Dockerfile (auto-selected based on DATA_NONREL_TYPE if not set)
- `DATA_REL_SOURCEFILE` - Path to database import file
- AWS credentials and ECR repository settings

## Running the Build Script

### Basic Usage
Open a terminal in the project root and run the build script with desired flags:

```bash
bash build/scripts/docker-build.sh [--rebuild-app] [--rebuild-data] [--import-data]
```

**Note:** The script must be run from the project root directory. It will automatically change to the correct working directory and load configuration from `build/.env`.

The script will:
- Prompt for confirmation and show a summary of settings
- Start, rebuild, or import containers as requested
- Display status and logs for troubleshooting

### Available Flags
- `--rebuild-app`: Remove and rebuild the application container
- `--rebuild-data`: Remove and rebuild the data container
- `--import-data`: Import the specified data file into the data container's database

### Example Commands
```bash
# Navigate to project root first
cd /path/to/gb_rtqi_imagebuilder_pipeline

# Start containers with current configuration
bash build/scripts/docker-build.sh

# Rebuild only the application container
bash build/scripts/docker-build.sh --rebuild-app

# Rebuild data container and import database
bash build/scripts/docker-build.sh --rebuild-data --import-data

# Full rebuild of both containers
bash build/scripts/docker-build.sh --rebuild-app --rebuild-data
```

## Windows PowerShell Usage

You can run the build script from Windows PowerShell as follows:

```powershell
# Navigate to project root
cd C:\Users\DD09045\sites\gb_rtqi_imagebuilder_pipeline

# Run the build script
bash build/scripts/docker-build.sh [--rebuild-app] [--rebuild-data] [--import-data]
```

### PowerShell Specific Notes
- You must have Git Bash or another bash shell installed (e.g., via Git for Windows)
- Always use `bash` to invoke the script, even from PowerShell
- **Important:** Run the script from the project root directory
- For absolute paths if needed:
  ```powershell
  cd C:\Users\DD09045\sites\gb_rtqi_imagebuilder_pipeline
  & "C:\Program Files\Git\bin\bash.exe" build/scripts/docker-build.sh --rebuild-app
  ```
- File paths in `.env` should use forward slashes (`/`) or double backslashes (`\\`) for compatibility
- If you encounter permission issues, run PowerShell as Administrator
- Docker Desktop must be running before executing scripts

## Integration with ECS App Stack

### Cross-Repository Workflow
This ImageBuilder pipeline works with the ECS App Stack repository:

```bash
# After building containers here, you can use the ECS app build script
cd ../gb_rtqi_ecs_app_stack
bash build/scripts/app-build.sh
```

### Container Dependencies
- **App Container:** Contains RTQI application code and Apache/PHP runtime
- **Data Container:** PostgreSQL database with application schema
- **Shared Volumes:** Application data and logs shared between containers

## Database Import

You can import a database into the data container using the `--import-data` flag and the `DATA_REL_SOURCEFILE` variable in `.env`.

### Exporting a Database for Import
Use pgAdmin 4 or `pg_dump` to export your database:

**For psql import (recommended for most users):**
- Use the "Plain" format (`.sql`)
- You may compress with `.zip` or `.gz`
- Example: `pg_dump -h localhost -U postgres -d rtqi_db > rtqi_export.sql`

**For pg_restore import:**
- Use the "Custom" or "Tar" format (`.dump`, `.backup`, `.tar`)
- Example: `pg_dump -h localhost -U postgres -d rtqi_db -Fc > rtqi_export.dump`

### Supported Import Formats
- **`.sql`, `.zip`, `.gz`** → imported with `psql`
- **`.dump`, `.backup`, `.tar`** → imported with `pg_restore`

### Import Process
1. Set the path to your export file in `DATA_REL_SOURCEFILE` in `.env`
2. Run the import command:
   ```bash
   bash build/scripts/docker-build.sh --import-data
   ```
3. The script will detect the file type and use the correct import command inside the data container

### Database Import Notes
- For most users, exporting as "Plain" format (`.sql`) is recommended for compatibility
- For large or complex databases, "Custom" format (`.dump`) is recommended and will use `pg_restore`
- Check script output for import status and troubleshooting information
- Database will be imported into the configured database name in the data container

## Application Development Workflow

### Local Development Cycle
1. **Start Environment:**
   ```bash
   # From project root
   cd /path/to/gb_rtqi_imagebuilder_pipeline
   bash build/scripts/docker-build.sh
   ```

2. **Install Dependencies:**
   ```bash
   # Use local app-build script for this repository
   bash build/scripts/app-build.sh
   
   # Or navigate to ECS app stack for cross-repository dependency management
   cd ../gb_rtqi_ecs_app_stack
   bash build/scripts/app-build.sh
   ```

3. **Test Application:**
   ```bash
   # Health check
   curl http://localhost:8080/healthcheck.html
   
   # Test rate calculation
   curl -X GET "http://localhost:8080/index.php/rates/rates_table" \
     -H "Accept: application/json" \
     -d "state=CT&sic_code=1234&num_employees=10"
   ```

4. **Debug Issues:**
   ```bash
   # View application logs
   docker logs RTQi-app-container
   
   # Enter container for debugging
   docker exec -it RTQi-app-container bash
   ```

### Code Changes
When making code changes:
1. Modify files in `artifacts/sourcecode/`
2. Ensure you're in the project root directory
3. Rebuild application container: `bash build/scripts/docker-build.sh --rebuild-app`
4. Test changes locally before committing
5. Commit triggers ImageBuilder pipeline for AMI creation

## Troubleshooting

### Common Issues

**Permission Errors:**
- Check Docker daemon is running and accessible
- Verify file system permissions for volume mounts
- Run PowerShell as Administrator if on Windows

**AWS Authentication Failures:**
- Run `aws sso login --profile <profile>` manually
- Verify AWS CLI configuration and credentials
- Check ECR repository permissions

**Container Startup Failures:**
- Check port conflicts with other services
- Verify volume paths in `.env` exist and are accessible
- Review Docker logs for specific error messages

**Database Import Failures:**
- Verify `DATA_REL_SOURCEFILE` path is correct and file exists
- Check database file format matches expected import method
- Ensure data container is running before import

### Debug Commands
```bash
# Check Docker status
docker ps -a

# View container logs
docker logs RTQi-app-container
docker logs RTQi-data-container

# Check network connectivity
docker network ls
docker inspect <container_name>

# Test database connection
docker exec -it RTQi-data-container psql -U postgres -d rtqi_db

# Check application configuration
docker exec RTQi-app-container cat /etc/httpd/conf.d/httpd.conf
```

### Performance Troubleshooting
- **Timeout Issues:** Verify all timeouts are set to 300 seconds (5 minutes)
- **Slow API Calls:** Check Smith Group SOAP API availability
- **Database Performance:** Review query logs and connection pooling
- **Cache Issues:** Verify session cache is working correctly

## Container Access and Monitoring

### Application Access
- **Application URL:** http://localhost:<APP_HOST_PORT> (default: 8080)
- **Health Check:** http://localhost:<APP_HOST_PORT>/healthcheck.html
- **Rate API:** http://localhost:<APP_HOST_PORT>/index.php/rates/rates_table

### Database Access
- **Host:** localhost:<DATA_REL_HOST_PORT> (default: 5432)
- **Database:** rtqi_db (or as configured)
- **User/Password:** As configured in `.env`

### Container Management
```bash
# Stop all containers
docker stop RTQi-app-container RTQi-data-container

# Remove containers (use rebuild flags instead)
docker rm RTQi-app-container RTQi-data-container

# View resource usage
docker stats RTQi-app-container RTQi-data-container
```

## Integration with ImageBuilder Pipeline

### Local to Pipeline Workflow
1. **Develop Locally:** Use this local environment for development and testing
2. **Test Changes:** Verify application works with local containers
3. **Commit Code:** Push changes to repository
4. **Pipeline Trigger:** Commit automatically triggers ImageBuilder pipeline
5. **AMI Creation:** Pipeline creates new AMI with your changes
6. **ECS Deployment:** New AMI deployed through ECS app stack

### Configuration Sync
Ensure local development matches pipeline environment:
- Use same base images as ImageBuilder pipeline
- Sync configuration files between repositories
- Test with same timeout and caching settings

## Useful Files and Directories

### Configuration Files
- **`build/.env`** - Environment configuration for local containers
- **`build/scripts/docker-build.sh`** - Main build and container management script
- **`build/scripts/app-build.sh`** - Automated composer dependency installation script
- **`build/docker/app/`** - Application container definitions (PHP, Node.js, Python, Java)
- **`build/docker/data-rel/`** - Relational database container definitions (Postgres, MySQL, MariaDB)
- **`build/docker/data-nonrel/`** - Non-relational database container definitions (MongoDB, Neo4j)

### Application Files
- **`artifacts/sourcecode/`** - Main application code
- **`artifacts/container-install.sh`** - Container installation script
- **`artifacts/container-run.sh`** - Container startup script

### Documentation
- **`docs/index.html`** - Project documentation
- **`CONFIG-README.md`** - Configuration reference

## Performance Considerations

### Timeout Configuration
Ensure consistent timeout settings across all layers:
- **Application Load Balancer:** 480 seconds (8 minutes)
- **Apache/PHP/SOAP:** 300 seconds (5 minutes)
- **Session Cache:** 3600 seconds (1 hour)

### Resource Allocation
- **Memory:** Ensure sufficient memory for PHP processes and caching
- **CPU:** Monitor CPU usage during rate calculations
- **Storage:** Adequate space for logs and temporary files

## Cleaning Up

### Container Cleanup
```bash
# Stop and remove containers
bash build/scripts/docker-build.sh --rebuild-app --rebuild-data

# Or manually
docker stop RTQi-app-container RTQi-data-container
docker rm RTQi-app-container RTQi-data-container
```

### Volume Cleanup
```bash
# Remove unused volumes
docker volume prune

# Remove specific volumes
docker volume rm <volume_name>
```

---
For further help, contact your project lead, check the comments in each script file, or refer to the main project documentation in the `gb_rtqi_ecs_app_stack` repository.
