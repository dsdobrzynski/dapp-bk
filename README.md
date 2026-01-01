# RTQI ImageBuilder Pipeline
This repository provides the ImageBuilder pipeline for the Real Time Quote Integration (RTQI) application, creating Amazon Machine Images (AMIs) for deployment to AWS ECS infrastructure.

## Overview
The ImageBuilder pipeline automates the creation of optimized AMIs containing the RTQI application code, configurations, and dependencies. Commits to this repository trigger automated image builds that deploy to the Hartford HIG environment.

## Purpose
- **AMI Creation:** Builds standardized Amazon Machine Images for RTQI application deployment
- **Infrastructure as Code:** Manages application and infrastructure modules through version control
- **Automated Deployment:** Pipeline triggers on repository commits to build and deploy images
- **Environment Consistency:** Ensures consistent application environments across dev/test/prod

## Repository Structure

### Core Directories
- **`artifacts/`** - Application source code and installation scripts
- **`build/`** - Local development and container management tools
  - **`scripts/`** - Build automation scripts (docker-build.sh, app-build.sh)
  - **`docker/`** - Container definitions
    - **`app/`** - Application container definitions (Dockerfile-app-php, Dockerfile-app-node, Dockerfile-app-python, Dockerfile-app-java)
    - **`data-rel/`** - Relational database container definitions (Dockerfile-data-postgres, Dockerfile-data-mysql, Dockerfile-data-mariadb)
    - **`data-nonrel/`** - Non-relational database container definitions (Dockerfile-data-mongodb, Dockerfile-data-neo4j)
- **`imagebuilder_pipeline/`** - AWS ImageBuilder pipeline configuration
- **`docs/`** - Documentation and reference materials

### Key Components

**Application Code (`artifacts/sourcecode/`):**
- CodeIgniter PHP application with Smith Group SOAP API integration
- Configuration files for Apache, PHP, and application settings
- Dependencies managed through composer.json

**Build Scripts (`artifacts/`):**
- `container-install.sh` - Container setup and dependency installation
- `container-run.sh` - Container startup and service management
- `installs.sh` - System package installation and configuration
- `myscript.sh` - Custom application setup procedures

**Pipeline Configuration (`imagebuilder_pipeline/`):**
- `buildspec.yml` - AWS CodeBuild pipeline specification
- Infrastructure as Code templates for ImageBuilder resources

## HIG Environment Modifications

⚠️ **Important:** The following files have been modified for Hartford HIG environment integration. Review these files carefully before merging from Howell production codebase to prevent conflicts:

1. **`Config.php`** - Database connections and environment-specific settings
2. **`Common.php`** - Shared utility functions and HIG-specific configurations
3. **`Security.php`** - Authentication and authorization for Hartford environment
4. **`Producer.php`** - Rate calculation producer services
5. **`Rates.php`** - Insurance rate generation with session caching and timeout management
6. **`Sso.php`** - Single Sign-On integration for Hartford systems
7. **`Rohi_email.php`** - Email services for Return of Health Insurance notifications

### Key Modifications Made
- **Timeout Configuration:** All timeouts set to 300 seconds (5 minutes) for external API calls
- **Session Caching:** 1-hour cache expiration for Smith Group SOAP API responses
- **Hartford SSO:** Integration with Hartford authentication systems
- **Database Configuration:** PostgreSQL connection settings for Hartford environment
- **Security Settings:** Hartford-specific security policies and access controls

## Build Pipeline Workflow

### Automated Process
1. **Code Commit** → Repository change triggers ImageBuilder pipeline
2. **Environment Setup** → Base Amazon Linux 2 AMI with required packages
3. **Application Installation** → Copies artifacts and runs installation scripts
4. **Configuration** → Applies HIG-specific settings and security policies
5. **Image Creation** → Creates final AMI with application and dependencies
6. **Deployment** → New AMI available for ECS task definition updates

### Manual Triggers
```bash
# Trigger pipeline manually (requires AWS CLI and permissions)
aws imagebuilder start-image-pipeline-execution \
    --image-pipeline-arn arn:aws:imagebuilder:region:account:image-pipeline/rtqi-pipeline
```

## Local Development

For local development and testing, see the comprehensive guide in [build/README.md](build/README.md).

### Quick Start
```bash
# Navigate to project root
cd /path/to/gb_rtqi_imagebuilder_pipeline

# Set up local environment
cp build/.env.example build/.env
# Edit .env with your configuration

# Build and start containers
bash build/scripts/docker-build.sh

# Install dependencies
bash build/scripts/app-build.sh
```

**Note:** All scripts must be run from the project root directory.

## Integration with ECS App Stack

This ImageBuilder pipeline works in conjunction with the `gb_rtqi_ecs_app_stack` repository:

- **Source Code:** Application code maintained in this repository's `artifacts/sourcecode/`
- **Infrastructure:** ECS infrastructure defined in the app stack repository
- **Deployment:** AMIs created here are referenced in ECS task definitions
- **Configuration:** Shared configuration files synchronized between repositories

## Performance Optimizations

### Timeout Management
The application implements a comprehensive timeout strategy:
- **Smith Group SOAP APIs:** 300 seconds (5 minutes)
- **PHP Execution Time:** 300 seconds
- **Apache Server Timeout:** 300 seconds
- **Session Cache:** 3600 seconds (1 hour)

### Caching Strategy
- **Session-based caching** for Smith Group API responses
- **1-hour cache expiration** to balance performance and data freshness
- **Automatic cache invalidation** for parameter changes

## Testing and Validation

### AMI Testing
```bash
# Launch test instance from new AMI
aws ec2 run-instances \
    --image-id ami-xxxxxxxxx \
    --instance-type t3.micro \
    --key-name your-key-pair

# Validate application startup
curl http://instance-ip/healthcheck.html
```

### Application Testing
```bash
# Test rate calculation endpoints
curl -X GET "http://instance-ip/index.php/rates/rates_table" \
  -H "Accept: application/json" \
  -d "state=CT&sic_code=1234&num_employees=10"
```

## Troubleshooting

### Common Issues

**AMI Build Failures:**
- Check ImageBuilder pipeline logs in CloudWatch
- Verify base AMI availability in target region
- Review artifact installation scripts for errors

**Application Startup Issues:**
- Verify Apache configuration in created AMI
- Check PHP extensions and dependencies
- Review system service startup logs

**Performance Issues:**
- Monitor Smith Group API response times
- Check session cache hit/miss rates
- Verify timeout configurations are consistent

### Debug Commands
```bash
# Check AMI build status
aws imagebuilder get-image-pipeline --image-pipeline-arn <pipeline-arn>

# View build logs
aws logs get-log-events --log-group-name /aws/imagebuilder/rtqi-pipeline

# Test application in container
bash build/build.sh --rebuild-app
docker logs RTQi-app-container
```

## Security Considerations

- **Secrets Management:** Sensitive data stored in AWS Secrets Manager, not in AMI
- **Access Control:** IAM roles restrict ImageBuilder and instance permissions
- **Network Security:** AMIs deployed in private subnets with security groups
- **Compliance:** Follows Hartford security standards and policies

## Maintenance

### Regular Updates
- **Base AMI:** Update base Amazon Linux 2 AMI monthly for security patches
- **Dependencies:** Update PHP packages and system libraries quarterly
- **Configuration:** Review timeout settings and performance metrics monthly

### Monitoring
- **Build Success Rate:** Monitor ImageBuilder pipeline success/failure rates
- **Performance Metrics:** Track application startup times and API response times
- **Security Scanning:** Regular vulnerability assessments of created AMIs

## Support and Documentation

- **Local Development:** [build/README.md](build/README.md) - Comprehensive local setup guide
- **ECS Deployment:** `gb_rtqi_ecs_app_stack` repository documentation
- **AWS ImageBuilder:** [AWS ImageBuilder Documentation](https://docs.aws.amazon.com/imagebuilder/)
- **CodeIgniter:** [CodeIgniter 3 User Guide](https://codeigniter.com/userguide3/)

## Related Resources
- **ECS App Stack:** `gb_rtqi_ecs_app_stack` - Infrastructure and deployment templates
- **Smith Group APIs:** External insurance rate calculation services
- **Hartford HIG Environment:** Internal Hartford development and deployment standards
