import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import chalk from 'chalk';
import inquirer from 'inquirer';
import Dockerode from 'dockerode';
import { config } from 'dotenv';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Find project root directory containing .env
 */
export async function findProjectRoot() {
  let current = process.cwd();
  const maxLevels = 5;

  for (let i = 0; i < maxLevels; i++) {
    try {
      await fs.access(path.join(current, '.env'));
      return current;
    } catch {}

    try {
      await fs.access(path.join(current, 'build', '.env'));
      return current;
    } catch {}

    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }

  return null;
}

/**
 * Load environment variables from .env
 */
export async function loadEnvironment(projectRoot) {
  let envFile = path.join(projectRoot, '.env');

  try {
    await fs.access(envFile);
  } catch {
    envFile = path.join(projectRoot, 'build', '.env');
  }

  try {
    await fs.access(envFile);
  } catch {
    console.error(chalk.red(`Error: Environment file not found in project root or build/`));
    console.log('Please create .env from .env.example');
    return null;
  }

  const envConfig = config({ path: envFile });
  
  if (envConfig.error) {
    console.error(chalk.red(`Error: Failed to load environment: ${envConfig.error.message}`));
    return null;
  }

  const env = envConfig.parsed;

  if (!env.PROJECT_NAME) {
    console.error(chalk.red('Error: PROJECT_NAME must be set in .env'));
    return null;
  }

  return env;
}

/**
 * Display build configuration
 */
export function displayConfiguration(env, options) {
  console.log();
  console.log(chalk.cyan.bold('Build Configuration'));
  console.log('='.repeat(50));
  console.log(`REBUILD_APP_CONTAINER:   ${options.rebuildApp || false}`);
  console.log(`REBUILD_DATA_CONTAINER:  ${options.rebuildData || false}`);
  console.log(`IMPORT_DATA:             ${options.importData || false}`);
  console.log(`PROJECT_NAME:            ${env.PROJECT_NAME || ''}`);
  console.log(`APP_TYPE:                ${env.APP_TYPE || 'php-apache'}`);
  console.log(`DATA_REL_TYPE:           ${env.DATA_REL_TYPE || 'postgres'}`);
  console.log(`DATA_NONREL_TYPE:        ${env.DATA_NONREL_TYPE || '(none)'}`);
  console.log('='.repeat(50));
  console.log();
}

/**
 * Build command handler
 */
export async function build(options) {
  console.log(chalk.cyan.bold('Docker App Build Kit'));
  console.log();

  // Find project root
  const projectRoot = await findProjectRoot();
  if (!projectRoot) {
    console.error(chalk.red('Error: Could not find project root with .env file'));
    process.exit(1);
  }

  console.log(`Project root: ${projectRoot}`);

  // Load environment
  const env = await loadEnvironment(projectRoot);
  if (!env) {
    process.exit(1);
  }

  // Display configuration
  displayConfiguration(env, options);

  // Ask for confirmation
  const answers = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'continue',
      message: 'Continue with these settings?',
      default: false,
    },
  ]);

  if (!answers.continue) {
    console.log(chalk.yellow('Aborted by user'));
    return;
  }

  // Create Docker client
  const docker = new Dockerode();

  // Check Docker connectivity
  try {
    await docker.ping();
    console.log(chalk.green('✓ Docker is running'));
  } catch (error) {
    console.error(chalk.red('✗ Unable to connect to Docker'));
    console.log();
    console.log(chalk.yellow('Docker does not appear to be running. Please:'));
    console.log('  1. Start Docker Desktop (or Docker daemon)');
    console.log('  2. Wait for Docker to fully start');
    console.log('  3. Try running this command again');
    console.log();
    console.log(chalk.cyan('Need help? Check:'));
    console.log('  • Windows: Ensure Docker Desktop is running in the system tray');
    console.log('  • Linux: Run "sudo systemctl start docker"');
    console.log('  • Mac: Ensure Docker Desktop is running in the menu bar');
    process.exit(1);
  }

  // Create Docker network
  if (!(await createDockerNetwork(docker, env))) {
    process.exit(1);
  }

  // Handle app container
  if (!(await handleAppContainer(docker, env, projectRoot, options.rebuildApp))) {
    process.exit(1);
  }

  // Handle data containers
  if (!(await handleDataContainers(docker, env, projectRoot, options.rebuildData, options.importData))) {
    process.exit(1);
  }

  console.log();
  console.log(chalk.green.bold('✓ Build completed successfully!'));
  displaySummary(env);
}

/**
 * Create Docker network if it doesn't exist
 */
async function createDockerNetwork(docker, env) {
  const networkName = `${env.PROJECT_NAME}-network`;
  console.log();
  console.log(chalk.cyan(`Docker Network: ${networkName}`));

  try {
    const networks = await docker.listNetworks({ filters: { name: [networkName] } });
    const networkExists = networks.some(net => net.Name === networkName);

    if (networkExists) {
      console.log(`Network ${networkName} already exists`);
      return true;
    }

    console.log(`Creating network: ${networkName}`);
    await docker.createNetwork({ Name: networkName });
    console.log(chalk.green(`✓ Network ${networkName} created`));
    return true;
  } catch (error) {
    console.error(chalk.red(`Error: Failed to create network: ${error.message}`));
    return false;
  }
}

/**
 * Handle application container build/start
 */
async function handleAppContainer(docker, env, projectRoot, rebuild) {
  const containerName = `${env.PROJECT_NAME}-app-container`;
  console.log();
  console.log(chalk.cyan(`App Container: ${containerName}`));

  try {
    const container = docker.getContainer(containerName);
    const info = await container.inspect();
    const exists = true;

    if (exists && !rebuild) {
      if (info.State.Status === 'running') {
        console.log(`Container ${containerName} is already running`);
        return true;
      } else {
        console.log(`Starting container ${containerName}`);
        await container.start();
        return true;
      }
    }

    if (exists && rebuild) {
      console.log('Removing existing container for rebuild');
      if (info.State.Status === 'running') {
        await container.stop();
      }
      await container.remove({ v: true });
    }
  } catch (error) {
    // Container doesn't exist, continue to build
  }

  // Build new container
  return await buildAppContainer(docker, env, projectRoot, containerName);
}

/**
 * Build and run application container
 */
async function buildAppContainer(docker, env, projectRoot, containerName) {
  const appType = env.APP_TYPE || 'php-apache';
  const dockerfile = env.APP_DOCKERFILE || getDefaultDockerfile(appType);
  const dockerfilePath = path.join(projectRoot, dockerfile);

  try {
    await fs.access(dockerfilePath);
  } catch {
    console.error(chalk.red(`Error: Dockerfile not found: ${dockerfilePath}`));
    return false;
  }

  console.log(`Building app container from: ${dockerfile}`);

  try {
    // Build image
    const stream = await docker.buildImage(
      {
        context: projectRoot,
        src: ['.'],
      },
      {
        dockerfile: dockerfile,
        t: containerName,
        buildargs: {
          ...(env.APP_BASE_IMAGE    ? { BASE_IMAGE: env.APP_BASE_IMAGE }           : {}),
          ...(env.DATA_REL_TYPE     ? { DATA_REL_TYPE: env.DATA_REL_TYPE }         : {}),
          ...(env.DATA_NONREL_TYPE  ? { DATA_NONREL_TYPE: env.DATA_NONREL_TYPE }   : {}),
        },
      }
    );

    await new Promise((resolve, reject) => {
      docker.modem.followProgress(stream, (err, res) => (err ? reject(err) : resolve(res)), (event) => {
        if (event.stream) {
          process.stdout.write(event.stream);
        }
      });
    });

    // Run container
    const networkName = `${env.PROJECT_NAME}-network`;
    const hostPort = env.APP_HOST_PORT || '8080';
    const containerPort = getContainerPort(appType);

    const createOptions = {
      name: containerName,
      Image: containerName,
      HostConfig: {
        NetworkMode: networkName,
        PortBindings: {
          [`${containerPort}/tcp`]: [{ HostPort: hostPort }],
        },
      },
      ExposedPorts: {
        [`${containerPort}/tcp`]: {},
      },
    };

    // Add volume mounts if specified
    if (env.APP_HOST_VOLUME_PATH) {
      createOptions.HostConfig.Binds = [
        `${env.APP_HOST_VOLUME_PATH}:${env.APP_CONTAINER_VOLUME_PATH || '/var/www/html'}:rw`,
      ];
    }

    const container = await docker.createContainer(createOptions);
    await container.start();

    console.log(chalk.green(`✓ Container ${containerName} started successfully`));
    console.log(`Access at: http://localhost:${hostPort}`);
    return true;
  } catch (error) {
    console.error(chalk.red(`Error: Failed to build/run container: ${error.message}`));
    return false;
  }
}

/**
 * Handle database containers
 */
async function handleDataContainers(docker, env, projectRoot, rebuild, importData) {
  if (env.DATA_REL_TYPE) {
    if (!(await handleRelationalDatabase(docker, env, projectRoot, rebuild))) {
      return false;
    }
  }

  if (env.DATA_NONREL_TYPE) {
    if (!(await handleNonRelationalDatabase(docker, env, projectRoot, rebuild))) {
      return false;
    }
  }

  return true;
}

/**
 * Handle relational database container
 */
async function handleRelationalDatabase(docker, env, projectRoot, rebuild) {
  const containerName = `${env.PROJECT_NAME}-data-rel-container`;
  console.log();
  console.log(chalk.cyan(`Relational Database: ${containerName}`));

  try {
    const container = docker.getContainer(containerName);
    const info = await container.inspect();

    if (!rebuild) {
      if (info.State.Status === 'running') {
        console.log(`Container ${containerName} is already running`);
        return true;
      }
      console.log(`Starting container ${containerName}`);
      await container.start();
      return true;
    }

    console.log('Removing existing container for rebuild');
    if (info.State.Status === 'running') {
      await container.stop();
    }
    await container.remove({ v: true });
  } catch (error) {
    // Container doesn't exist, continue to build
  }

  return await buildDataContainer(docker, env, projectRoot, containerName, 'rel');
}

/**
 * Handle non-relational database container
 */
async function handleNonRelationalDatabase(docker, env, projectRoot, rebuild) {
  const containerName = `${env.PROJECT_NAME}-data-nonrel-container`;
  console.log();
  console.log(chalk.cyan(`Non-Relational Database: ${containerName}`));

  try {
    const container = docker.getContainer(containerName);
    const info = await container.inspect();

    if (!rebuild) {
      if (info.State.Status === 'running') {
        console.log(`Container ${containerName} is already running`);
        return true;
      }
      console.log(`Starting container ${containerName}`);
      await container.start();
      return true;
    }

    console.log('Removing existing container for rebuild');
    if (info.State.Status === 'running') {
      await container.stop();
    }
    await container.remove({ v: true });
  } catch (error) {
    // Container doesn't exist, continue to build
  }

  return await buildDataContainer(docker, env, projectRoot, containerName, 'nonrel');
}

/**
 * Build and run a data container (rel or nonrel)
 */
async function buildDataContainer(docker, env, projectRoot, containerName, kind) {
  const isRel = kind === 'rel';
  const dataType = isRel ? (env.DATA_REL_TYPE || 'postgres') : env.DATA_NONREL_TYPE;
  const dockerfileKey = isRel ? 'DATA_REL_DOCKERFILE' : 'DATA_NONREL_DOCKERFILE';
  const dockerfile = env[dockerfileKey] || getDefaultDataDockerfile(dataType);
  const dockerfilePath = path.join(projectRoot, dockerfile);

  try {
    await fs.access(dockerfilePath);
  } catch {
    console.error(chalk.red(`Error: Dockerfile not found: ${dockerfilePath}`));
    return false;
  }

  console.log(`Building data container from: ${dockerfile}`);

  try {
    const imagePrefix = isRel ? 'data-rel' : 'data-nonrel';
    const imageName = `${env.PROJECT_NAME}-${imagePrefix}-image`;

    const stream = await docker.buildImage(
      { context: projectRoot, src: ['.'] },
      { dockerfile, t: imageName }
    );

    await new Promise((resolve, reject) => {
      docker.modem.followProgress(stream, (err, res) => (err ? reject(err) : resolve(res)), (event) => {
        if (event.stream) process.stdout.write(event.stream);
      });
    });

    return await runDataContainer(docker, env, containerName, imageName, kind);
  } catch (error) {
    console.error(chalk.red(`Error: Failed to build data container: ${error.message}`));
    return false;
  }
}

/**
 * Run data container with type-specific configuration
 */
async function runDataContainer(docker, env, containerName, imageName, kind) {
  const isRel = kind === 'rel';
  const dataType = isRel ? (env.DATA_REL_TYPE || 'postgres') : env.DATA_NONREL_TYPE;
  const hostPortKey = isRel ? 'DATA_REL_HOST_PORT' : 'DATA_NONREL_HOST_PORT';
  const hostPort = env[hostPortKey] || getDefaultDataPort(dataType);

  console.log(`Starting container: ${containerName} on port ${hostPort}`);

  try {
    const createOptions = buildDataContainerConfig(env, containerName, imageName, kind);
    const container = await docker.createContainer(createOptions);
    await container.start();
    console.log(chalk.green('✓ Data container started successfully'));
    return true;
  } catch (error) {
    console.error(chalk.red(`Error: Failed to run data container: ${error.message}`));
    return false;
  }
}

/**
 * Build createContainer options for a data container (exported for testing)
 */
export function buildDataContainerConfig(env, containerName, imageName, kind) {
  const isRel = kind === 'rel';
  const dataType = isRel ? (env.DATA_REL_TYPE || 'postgres') : env.DATA_NONREL_TYPE;
  const networkName = `${env.PROJECT_NAME}-network`;
  const hostPortKey = isRel ? 'DATA_REL_HOST_PORT' : 'DATA_NONREL_HOST_PORT';
  const containerPortKey = isRel ? 'DATA_REL_CONTAINER_PORT' : 'DATA_NONREL_CONTAINER_PORT';
  const hostPort = env[hostPortKey] || getDefaultDataPort(dataType);
  const containerPort = env[containerPortKey] || getDefaultDataPort(dataType);

  const createOptions = {
    name: containerName,
    Image: imageName,
    Env: buildDataEnvVars(env, dataType, isRel),
    HostConfig: {
      NetworkMode: networkName,
      PortBindings: {
        [`${containerPort}/tcp`]: [{ HostPort: hostPort }],
      },
    },
    ExposedPorts: {
      [`${containerPort}/tcp`]: {},
    },
  };

  const hostVolKey = isRel ? 'DATA_REL_HOST_VOLUME_PATH' : 'DATA_NONREL_HOST_VOLUME_PATH';
  const containerVolKey = isRel ? 'DATA_REL_CONTAINER_VOLUME_PATH' : 'DATA_NONREL_CONTAINER_VOLUME_PATH';
  if (env[hostVolKey]) {
    createOptions.HostConfig.Binds = [
      `${env[hostVolKey]}:${env[containerVolKey] || getDefaultDataVolume(dataType)}:rw`,
    ];
  }

  return createOptions;
}

/**
 * Build Env array for a data container (exported for testing)
 */
export function buildDataEnvVars(env, dataType, isRel) {
  const prefix = isRel ? 'DATA_REL' : 'DATA_NONREL';
  const dbName = env[`${prefix}_NAME`] || 'appdb';
  const dbUser = env[`${prefix}_USERNAME`] || 'appuser';
  const dbPassword = env[`${prefix}_PASSWORD`] || 'apppass';

  switch (dataType) {
    case 'mysql':
    case 'mariadb':
      return [
        `MYSQL_DATABASE=${dbName}`,
        `MYSQL_USER=${dbUser}`,
        `MYSQL_PASSWORD=${dbPassword}`,
        `MYSQL_ROOT_PASSWORD=${dbPassword}`,
      ];
    case 'mongodb':
      return [
        `MONGO_INITDB_DATABASE=${dbName}`,
        `MONGO_INITDB_ROOT_USERNAME=${dbUser}`,
        `MONGO_INITDB_ROOT_PASSWORD=${dbPassword}`,
      ];
    case 'neo4j':
      return [`NEO4J_AUTH=${dbUser}/${dbPassword}`];
    case 'postgres':
    default:
      return [
        `POSTGRES_DB=${dbName}`,
        `POSTGRES_USER=${dbUser}`,
        `POSTGRES_PASSWORD=${dbPassword}`,
      ];
  }
}

/**
 * Get default Dockerfile path for data type (exported for testing)
 */
export function getDefaultDataDockerfile(dataType) {
  const dockerfiles = {
    'mysql':    'docker/data-rel/Dockerfile-data-mysql',
    'mariadb':  'docker/data-rel/Dockerfile-data-mariadb',
    'postgres': 'docker/data-rel/Dockerfile-data-postgres',
    'mongodb':  'docker/data-nonrel/Dockerfile-data-mongodb',
    'neo4j':    'docker/data-nonrel/Dockerfile-data-neo4j',
  };
  return dockerfiles[dataType] || `docker/data-rel/Dockerfile-data-${dataType}`;
}

/**
 * Get default port for a database type
 */
function getDefaultDataPort(dataType) {
  if (dataType === 'mysql' || dataType === 'mariadb') return '3306';
  if (dataType === 'neo4j') return '7687';
  if (dataType === 'mongodb') return '27017';
  return '5432';
}

/**
 * Get default container volume path for a data type
 */
function getDefaultDataVolume(dataType) {
  if (dataType === 'postgres') return '/var/lib/postgresql/data';
  if (dataType === 'mongodb') return '/data/db';
  if (dataType === 'neo4j') return '/data';
  return '/var/lib/mysql';
}

/**
 * Get default Dockerfile path for app type
 */
function getDefaultDockerfile(appType) {
  const dockerfiles = {
    'php-apache': 'docker/app/Dockerfile-app-php',
    'node': 'docker/app/Dockerfile-app-node',
    'python': 'docker/app/Dockerfile-app-python',
    'java': 'docker/app/Dockerfile-app-java',
  };
  return dockerfiles[appType] || dockerfiles['php-apache'];
}

/**
 * Get default container port for app type
 */
function getContainerPort(appType) {
  const ports = {
    'php-apache': '80',
    'node': '3000',
    'python': '5000',
    'java': '8080',
  };
  return ports[appType] || '80';
}

/**
 * Display container summary
 */
function displaySummary(env) {
  console.log();
  console.log(chalk.cyan.bold('Container Summary'));
  console.log('='.repeat(70));

  const appContainer = `${env.PROJECT_NAME}-app-container`;
  const hostPort = env.APP_HOST_PORT || '8080';

  console.log(`Container: ${appContainer}`);
  console.log(`URL:       http://localhost:${hostPort}`);
  console.log(`Status:    Running`);
  console.log('='.repeat(70));
}
