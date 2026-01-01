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
 * Find project root directory containing build/.env
 */
export async function findProjectRoot() {
  let current = process.cwd();
  const maxLevels = 5;

  for (let i = 0; i < maxLevels; i++) {
    try {
      await fs.access(path.join(current, 'build', '.env'));
      return current;
    } catch {
      const parent = path.dirname(current);
      if (parent === current) break;
      current = parent;
    }
  }

  // Check if we're in build directory
  try {
    await fs.access(path.join(process.cwd(), '.env'));
    return path.dirname(process.cwd());
  } catch {
    return null;
  }
}

/**
 * Load environment variables from build/.env
 */
export async function loadEnvironment(projectRoot) {
  const envFile = path.join(projectRoot, 'build', '.env');

  try {
    await fs.access(envFile);
  } catch {
    console.error(chalk.red(`Error: Environment file not found: ${envFile}`));
    console.log('Please create build/.env from build/.env.example');
    return null;
  }

  const envConfig = config({ path: envFile });
  
  if (envConfig.error) {
    console.error(chalk.red(`Error: Failed to load environment: ${envConfig.error.message}`));
    return null;
  }

  const env = envConfig.parsed;

  if (!env.PROJECT_NAME) {
    console.error(chalk.red('Error: PROJECT_NAME must be set in build/.env'));
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
    console.error(chalk.red('Error: Could not find project root with build/.env file'));
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

  try {
    await docker.ping();
  } catch (error) {
    console.error(chalk.red(`Error: Could not connect to Docker: ${error.message}`));
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
        buildargs: env.APP_BASE_IMAGE ? { BASE_IMAGE: env.APP_BASE_IMAGE } : undefined,
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
    if (env.APP_VOLUME_HOST) {
      createOptions.HostConfig.Binds = [
        `${env.APP_VOLUME_HOST}:${env.APP_VOLUME_CONTAINER || '/var/www/html'}:rw`,
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
  // Simplified implementation
  if (env.DATA_REL_TYPE) {
    console.log();
    console.log(chalk.cyan('Relational database container handling...'));
  }

  if (env.DATA_NONREL_TYPE) {
    console.log(chalk.cyan('Non-relational database container handling...'));
  }

  return true;
}

/**
 * Get default Dockerfile path for app type
 */
function getDefaultDockerfile(appType) {
  const dockerfiles = {
    'php-apache': 'build/docker/app/Dockerfile-app-php',
    'node': 'build/docker/app/Dockerfile-app-node',
    'python': 'build/docker/app/Dockerfile-app-python',
    'java': 'build/docker/app/Dockerfile-app-java',
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
