# RTQi Configuration Management

## Overview

The RTQi application now uses a flexible, secure configuration system with multiple sources and clear precedence rules.

## Configuration Precedence

Values are loaded in the following order (highest to lowest priority):

1. **Environment Variables** - System or Docker environment variables
2. **`.env` File** - Local development configuration file (project root)
3. **`secret.json`** - Local JSON configuration file  
4. **AWS Secrets Manager** - Cloud-based secrets (production environments)

This means:
- Environment variables ALWAYS win
- .env file overrides secret.json
- secret.json overrides AWS Secrets Manager
- AWS Secrets Manager is the fallback

## File Locations

### `.env` File
**Location:** Project root (`/path/to/gb_rtqi_imagebuilder_pipeline/.env`)

This file contains environment-specific settings for local development:
```
DBHOST=RTQi-data-container
DBPORT=5432
ENVIRONMENT=local
```

**Important:** 
- `.env` is in `.gitignore` - never commit it!
- Use `.env.example` as a template
- Copy `.env.example` to `.env` and fill in your values

### `secret.json` File  
**Location:** Application directory (`artifacts/sourcecode/assets/awsphp/secret.json`)

Fallback configuration for when .env doesn't exist. Still used but environment variables take priority.

### `secret.php` File
**Location:** Application directory (`artifacts/sourcecode/assets/awsphp/secret.php`)

The configuration loader that:
1. Loads .env file if it exists
2. Attempts to load from AWS Secrets Manager
3. Falls back to secret.json
4. Merges all sources with proper precedence
5. Exposes configuration to the application

## Usage

### Local Development

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your local settings:
   ```bash
   nano .env
   # or
   code .env
   ```

3. Key settings for Docker:
   ```
   DBHOST=RTQi-data-container
   DBPORT=5432
   POSTGRES_ENABLED=true
   ```

4. Run your application - it will automatically load .env

### Docker Deployment

Pass environment variables to Docker containers:

```bash
docker run -d \
  -e DBHOST=RTQi-data-container \
  -e DBPORT=5432 \
  -e ENVIRONMENT=local \
  ...other vars... \
  your-image
```

Or use Docker Compose with `env_file`:

```yaml
services:
  app:
    image: your-image
    env_file:
      - .env
```

### AWS/Cloud Deployment

In AWS environments:
1. Set environment variables in ECS Task Definitions
2. Or use AWS Secrets Manager (automatically loaded by secret.php)
3. Environment variables still override Secrets Manager values

## Configuration Keys

### Database
```
DBUSER, DBPASS, DBHOST, DBNAME, DBPORT, DBDRIVER, DBPREFIX
DBUSER_PGSQL, DBPASS_PGSQL, DBHOST_PGSQL, DBNAME_PGSQL, DBPORT_PGSQL, DBDRIVER_PGSQL
POSTGRES_ENABLED
```

### AWS S3
```
S3_BUCKET_NAME, S3_SECONDARY_BUCKET_NAME
S3_ACCESS_KEY, S3_SECRET_KEY, S3_REGION
```

### Security
```
ENCRYPTION_KEY, ENCRYPT_SEED
```

### Features
```
BEAM_ENABLED, CIAM_ENABLED, PHPINFO_ENABLED
QUOTES_PLATFORM_ENABLED, ANTIVIRUS_SCAN_STATUS
ADMIN_CREATION_DATE_ENABLED, LOCAL_ENABLED
```

### Environment
```
ENVIRONMENT, SERVER_ROLE, LOG_THRESHOLD
BASE_URL, BASE_ADMIN_URL
```

See `.env.example` for the complete list.

## Security Best Practices

### ✅ DO
- Use `.env` for local development
- Use environment variables in Docker/cloud
- Use AWS Secrets Manager for production secrets
- Keep `.env` out of version control
- Use `.env.example` as documentation

### ❌ DON'T
- Commit `.env` to Git
- Hard-code sensitive values in code
- Share `.env` files via email/Slack
- Use production credentials in `.env`

## Migrating from secret.json Only

Old way (secret.json only):
```json
{
  "dbhost": "localhost",
  "dbport": "3306"
}
```

New way (environment variables + fallback):

**.env file:**
```
DBHOST=RTQi-data-container
DBPORT=5432
```

**secret.json** (still works as fallback):
```json
{
  "dbhost": "localhost",
  "dbport": "3306"  
}
```

The application will use `RTQi-data-container:5432` from .env, not the values from secret.json.

## Troubleshooting

### Configuration not loading from .env

1. Check file exists:
   ```bash
   ls -la /path/to/project/.env
   ```

2. Check file permissions:
   ```bash
   chmod 644 .env
   ```

3. Verify format (no spaces around `=`):
   ```
   # GOOD
   DBHOST=localhost
   
   # BAD
   DBHOST = localhost
   ```

### Values not being overridden

Check precedence:
1. Are environment variables set? `printenv | grep DB`
2. Is .env in the right location?
3. Is secret.json malformed? Validate JSON

### Container can't find .env

Mount .env as a volume or pass vars directly:
```bash
docker run -v $(pwd)/.env:/app/.env ...
# OR
docker run -e DBHOST=value -e DBPORT=value ...
```

## Examples

### Example 1: Local Development with Docker

**.env:**
```
DBHOST=RTQi-data-container
DBPORT=5432
DBUSER=rtqiuser
DBPASS=rtqi8675309
ENVIRONMENT=local
```

Result: App connects to PostgreSQL in Docker container

### Example 2: Cloud Deployment

**ECS Task Definition:**
```json
{
  "environment": [
    {"name": "DBHOST", "value": "prod-db.amazonaws.com"},
    {"name": "DBPORT", "value": "5432"},
    {"name": "ENVIRONMENT", "value": "production"}
  ]
}
```

Result: App uses environment variables, ignores .env and secret.json

### Example 3: Mixed Configuration

**.env:**
```
DBHOST=RTQi-data-container
ENVIRONMENT=local
```

**secret.json:**
```json
{
  "dbhost": "old-host",
  "dbport": "3306",
  "dbuser": "admin"
}
```

Result:
- `dbhost` = `RTQi-data-container` (from .env)
- `dbport` = `3306` (from secret.json, no override)
- `dbuser` = `admin` (from secret.json)
- `environment` = `local` (from .env)

## Support

For questions or issues with configuration:
1. Check this README
2. Review `.env.example` for required variables
3. Validate your configuration sources
4. Check application logs for loading errors

---

**Last Updated:** November 22, 2025  
**Version:** 2.0 - Environment Variable Support
