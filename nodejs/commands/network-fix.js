import { execSync } from 'child_process';
import chalk from 'chalk';
import { platform } from 'os';

/**
 * Network fix command handler
 */
export async function networkFix() {
  console.log(chalk.cyan.bold('Docker Network Fix'));
  console.log();

  if (platform() === 'win32') {
    fixWindowsNetwork();
  } else {
    fixLinuxNetwork();
  }
}

/**
 * Fix Docker network on Windows
 */
function fixWindowsNetwork() {
  console.log('Fixing Docker network on Windows...');

  const commands = [
    { description: 'Restarting Docker Desktop...', command: 'powershell -Command "Restart-Service docker"' },
    { description: 'Flushing DNS cache...', command: 'powershell -Command "Clear-DnsClientCache"' },
    { description: 'Resetting Winsock...', command: 'powershell -Command "netsh winsock reset"' },
  ];

  for (const { description, command } of commands) {
    console.log(description);
    try {
      execSync(command, { stdio: 'inherit' });
      console.log(chalk.green(`✓ Success: ${description}`));
    } catch (error) {
      console.log(chalk.yellow(`✗ Failed: ${description}`));
    }
  }

  console.log();
  console.log(chalk.cyan('Network fix completed. You may need to restart your computer for all changes to take effect.'));
}

/**
 * Fix Docker network on Linux
 */
function fixLinuxNetwork() {
  console.log('Fixing Docker network on Linux...');

  const commands = [
    { description: 'Restarting Docker service...', command: 'sudo systemctl restart docker' },
    { description: 'Flushing iptables...', command: 'sudo iptables -F' },
  ];

  for (const { description, command } of commands) {
    console.log(description);
    try {
      execSync(command, { stdio: 'inherit' });
      console.log(chalk.green(`✓ Success: ${description}`));
    } catch (error) {
      console.log(chalk.yellow(`✗ Failed: ${description}`));
    }
  }

  console.log();
  console.log(chalk.green.bold('✓ Network fix completed!'));
}
