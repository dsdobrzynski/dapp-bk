# Release Notes

## v1.0.0-rc1 (Release Candidate 1) - January 5, 2026

### Overview

First release candidate of Docker App Build Kit - a comprehensive Docker container build and management toolkit for multi-stack application development.

### Features

- **Multi-language implementations**: PHP, Python, and Node.js versions
- **Application support**: PHP-Apache, Node.js, Python, Java
- **Database support**: PostgreSQL, MySQL, MariaDB, MongoDB, Neo4j
- **Build commands**: Container building, rebuilding, and management
- **Volume mounting**: Automatic project root mounting with configurable paths
- **Network management**: Automatic Docker network creation and configuration
- **Environment configuration**: `.env` based configuration with comprehensive options

### Commands Available

- `build` - Build and manage Docker containers with options:
  - `--rebuild-app` - Force rebuild application container
  - `--rebuild-data` - Force rebuild database container
  - `--import-data` - Import data into database
  - `--no-cache` - Build without using Docker cache
- `composer:install` - Install Composer dependencies in running container
- `network:fix` - Fix Docker networking issues (platform-specific)

### Testing Status

#### ✅ Tested Combinations
- **php-apache + PostgreSQL** - Fully tested and working

#### ⚠️ Untested Combinations
- php-apache + MySQL
- php-apache + MariaDB
- php-apache + MongoDB
- php-apache + Neo4j
- node + (all databases)
- python + (all databases)
- java + (all databases)

### Known Limitations

1. **Data Container Building**: Only relational databases implemented; non-relational database container handling is stubbed
2. **Data Import**: `--import-data` functionality not yet implemented
3. **Python and Node.js implementations**: May not have all features synced with PHP version
4. **Limited testing**: Only php-apache with PostgreSQL has been thoroughly tested

### Installation

**PHP (via Composer):**
```bash
composer require dsdobrzynski/dapp-bk
vendor/bin/dapp-bk build
```

**Python (via pip):**
```bash
pip install dapp-bk
dapp-bk-py build
```

**Node.js (via npm):**
```bash
npm install -g @dsdobrzynski/dapp-bk
dapp-bk-node build
```

### Requirements

- Docker Desktop
- PHP >= 8.2 (for PHP version) OR Python >= 3.7 (for Python version) OR Node.js >= 16.0.0 (for Node.js version)
- Composer (for PHP version) / pip (for Python version) / npm (for Node.js version)

### Breaking Changes

N/A - Initial release

### Bug Fixes

N/A - Initial release

### Contributors

- @dsdobrzynski

### Next Steps for v1.0.0

- [ ] Test all application type and database combinations
- [ ] Implement non-relational database container handling
- [ ] Implement data import functionality
- [ ] Sync Python and Node.js implementations with PHP features
- [ ] Add comprehensive unit and integration tests
- [ ] Performance optimization for container builds

---

For detailed documentation, see [README.md](README.md).

For issues and support, visit [GitHub Issues](https://github.com/dsdobrzynski/dapp-bk/issues).
