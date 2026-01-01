import fs from 'fs/promises';
import path from 'path';
import chalk from 'chalk';
import Dockerode from 'dockerode';
import { findProjectRoot } from './build.js';

/**
 * Composer install command handler
 */
export async function composerInstall() {
  console.log(chalk.cyan.bold('App Container Composer Install'));
  console.log();

  // Find project root
  const projectRoot = await findProjectRoot();
  if (!projectRoot) {
    console.error(chalk.red('Error: Could not find project root'));
    process.exit(1);
  }

  // Read container name
  const containersFile = path.join(projectRoot, 'build', 'out', 'containers-names.txt');
  
  try {
    await fs.access(containersFile);
  } catch {
    console.error(chalk.red(`Error: containers-names.txt not found at ${containersFile}`));
    console.log('Run the build command first to create containers');
    process.exit(1);
  }

  const content = await fs.readFile(containersFile, 'utf-8');
  const appContainerName = content.trim().split('\n')[0];

  console.log(`Container: ${appContainerName}`);

  // Create Docker client
  const docker = new Dockerode();
  const container = docker.getContainer(appContainerName);

  try {
    const info = await container.inspect();

    if (info.State.Status !== 'running') {
      console.error(chalk.red(`Error: Container '${appContainerName}' is not running (status: ${info.State.Status})`));
      process.exit(1);
    }
  } catch (error) {
    console.error(chalk.red(`Error: Container '${appContainerName}' not found`));
    process.exit(1);
  }

  console.log(chalk.green('✓ Container is running'));

  // Check for composer.json
  const projectRootContainer = '/var/www/html';
  console.log('Checking for composer.json...');

  try {
    const exec = await container.exec({
      Cmd: ['test', '-f', `${projectRootContainer}/composer.json`],
      AttachStdout: true,
      AttachStderr: true,
    });

    const stream = await exec.start({ Detach: false });
    await new Promise((resolve, reject) => {
      stream.on('end', resolve);
      stream.on('error', reject);
    });

    const inspectResult = await exec.inspect();
    if (inspectResult.ExitCode !== 0) {
      console.log(chalk.yellow(`Warning: No composer.json found in ${projectRootContainer}`));
      console.log('Skipping Composer install');
      return;
    }
  } catch (error) {
    console.log(chalk.yellow(`Warning: No composer.json found in ${projectRootContainer}`));
    console.log('Skipping Composer install');
    return;
  }

  console.log(chalk.green('✓ Found composer.json'));

  // Check for Composer
  console.log('Checking for Composer...');

  try {
    const exec = await container.exec({
      Cmd: ['which', 'composer'],
      AttachStdout: true,
      AttachStderr: true,
    });

    const stream = await exec.start({ Detach: false });
    await new Promise((resolve) => {
      stream.on('end', resolve);
    });

    const inspectResult = await exec.inspect();
    if (inspectResult.ExitCode !== 0) {
      console.log('Composer not found, installing...');
      if (!(await installComposer(container))) {
        process.exit(1);
      }
    } else {
      console.log(chalk.green('✓ Composer is installed'));
    }
  } catch (error) {
    console.log('Composer not found, installing...');
    if (!(await installComposer(container))) {
      process.exit(1);
    }
  }

  // Run composer install
  console.log('Running composer install...');

  try {
    const exec = await container.exec({
      Cmd: ['composer', 'install', '--no-interaction', '--optimize-autoloader'],
      AttachStdout: true,
      AttachStderr: true,
      WorkingDir: projectRootContainer,
    });

    const stream = await exec.start({ Detach: false });

    stream.on('data', (chunk) => {
      process.stdout.write(chunk.toString());
    });

    await new Promise((resolve, reject) => {
      stream.on('end', resolve);
      stream.on('error', reject);
    });

    const inspectResult = await exec.inspect();
    if (inspectResult.ExitCode !== 0) {
      console.error(chalk.red('Error: Composer install failed'));
      process.exit(1);
    }

    console.log();
    console.log(chalk.green.bold('✓ Composer install completed successfully!'));
  } catch (error) {
    console.error(chalk.red(`Error: ${error.message}`));
    process.exit(1);
  }
}

/**
 * Install Composer in container
 */
async function installComposer(container) {
  console.log('Installing Composer...');

  try {
    // Download installer
    const downloadExec = await container.exec({
      Cmd: ['php', '-r', "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"],
      AttachStdout: true,
      AttachStderr: true,
    });

    let downloadStream = await downloadExec.start({ Detach: false });
    await new Promise((resolve) => {
      downloadStream.on('end', resolve);
    });

    const downloadResult = await downloadExec.inspect();
    if (downloadResult.ExitCode !== 0) {
      console.error(chalk.red('Error: Failed to download Composer installer'));
      return false;
    }

    // Run installer
    const installExec = await container.exec({
      Cmd: ['php', '/tmp/composer-setup.php', '--install-dir=/usr/local/bin', '--filename=composer'],
      AttachStdout: true,
      AttachStderr: true,
    });

    let installStream = await installExec.start({ Detach: false });
    await new Promise((resolve) => {
      installStream.on('end', resolve);
    });

    const installResult = await installExec.inspect();
    if (installResult.ExitCode !== 0) {
      console.error(chalk.red('Error: Failed to install Composer'));
      return false;
    }

    // Cleanup
    const cleanupExec = await container.exec({
      Cmd: ['rm', '/tmp/composer-setup.php'],
    });
    await cleanupExec.start({ Detach: true });

    console.log(chalk.green('✓ Composer installed successfully'));
    return true;
  } catch (error) {
    console.error(chalk.red(`Error: ${error.message}`));
    return false;
  }
}
