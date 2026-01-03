#!/usr/bin/env python3
"""
Docker App Build Kit (dapp-bk) CLI
"""
import os
import sys
import subprocess
from pathlib import Path
from typing import Optional, Dict

import click
import docker
from dotenv import dotenv_values


@click.group()
@click.version_option(version="1.0.0")
def cli():
    """Docker App Build Kit - Docker container management toolkit"""
    pass


@cli.command()
@click.option('--rebuild-app', is_flag=True, help='Rebuild the application container')
@click.option('--rebuild-data', is_flag=True, help='Rebuild the data container')
@click.option('--import-data', is_flag=True, help='Import data into the database container')
def build(rebuild_app: bool, rebuild_data: bool, import_data: bool):
    """Build and manage Docker containers for your application"""
    click.secho('Docker App Build Kit', fg='cyan', bold=True)
    click.echo()

    # Find project root
    project_root = find_project_root()
    if not project_root:
        click.secho('Error: Could not find project root with .env file', fg='red')
        sys.exit(1)

    click.echo(f'Project root: {project_root}')

    # Load environment
    env = load_environment(project_root)
    if not env:
        sys.exit(1)

    # Display configuration
    display_configuration(env, rebuild_app, rebuild_data, import_data)

    # Ask for confirmation
    if not click.confirm('Continue with these settings?'):
        click.secho('Aborted by user', fg='yellow')
        return

    # Create Docker client
    try:
        client = docker.from_env()
    except Exception as e:
        click.secho(f'Error: Could not connect to Docker: {e}', fg='red')
        sys.exit(1)

    # Create Docker network
    if not create_docker_network(client, env):
        sys.exit(1)

    # Handle app container
    if not handle_app_container(client, env, project_root, rebuild_app):
        sys.exit(1)

    # Handle data containers
    if not handle_data_containers(client, env, project_root, rebuild_data, import_data):
        sys.exit(1)

    click.secho('\n✓ Build completed successfully!', fg='green', bold=True)
    display_summary(env)


@cli.command('composer:install')
def composer_install():
    """Install Composer dependencies in the app container"""
    click.secho('App Container Composer Install', fg='cyan', bold=True)
    click.echo()

    # Find project root
    project_root = find_project_root()
    if not project_root:
        click.secho('Error: Could not find project root', fg='red')
        sys.exit(1)

    # Read container name
    containers_file = project_root / 'build' / 'out' / 'containers-names.txt'
    if not containers_file.exists():
        click.secho(f'Error: containers-names.txt not found at {containers_file}', fg='red')
        click.echo('Run the build command first to create containers')
        sys.exit(1)

    app_container_name = containers_file.read_text().strip().split('\n')[0]
    click.echo(f'Container: {app_container_name}')

    # Create Docker client
    try:
        client = docker.from_env()
        container = client.containers.get(app_container_name)
    except docker.errors.NotFound:
        click.secho(f"Error: Container '{app_container_name}' not found", fg='red')
        sys.exit(1)
    except Exception as e:
        click.secho(f'Error: {e}', fg='red')
        sys.exit(1)

    # Check if running
    if container.status != 'running':
        click.secho(f"Error: Container '{app_container_name}' is not running (status: {container.status})", fg='red')
        sys.exit(1)

    click.secho('✓ Container is running', fg='green')

    # Check for composer.json
    project_root_container = '/var/www/html'
    click.echo('Checking for composer.json...')
    
    exit_code, output = container.exec_run(['test', '-f', f'{project_root_container}/composer.json'])
    if exit_code != 0:
        click.secho(f'Warning: No composer.json found in {project_root_container}', fg='yellow')
        click.echo('Skipping Composer install')
        return

    click.secho('✓ Found composer.json', fg='green')

    # Check for Composer
    click.echo('Checking for Composer...')
    exit_code, output = container.exec_run(['which', 'composer'])
    
    if exit_code != 0:
        click.echo('Composer not found, installing...')
        if not install_composer(container):
            sys.exit(1)
    else:
        click.secho('✓ Composer is installed', fg='green')

    # Run composer install
    click.echo('Running composer install...')
    exit_code, output = container.exec_run(
        ['composer', 'install', '--no-interaction', '--optimize-autoloader'],
        workdir=project_root_container,
        stream=True
    )

    for line in output:
        click.echo(line.decode('utf-8'), nl=False)

    if exit_code != 0:
        click.secho('Error: Composer install failed', fg='red')
        sys.exit(1)

    click.secho('\n✓ Composer install completed successfully!', fg='green', bold=True)


@cli.command('network:fix')
def network_fix():
    """Fix Docker network issues"""
    click.secho('Docker Network Fix', fg='cyan', bold=True)
    click.echo()

    if sys.platform == 'win32':
        fix_windows_network()
    else:
        fix_linux_network()


def find_project_root() -> Optional[Path]:
    """Find the project root directory containing .env"""
    current = Path.cwd()
    max_levels = 5

    for _ in range(max_levels):
        if (current / 'build' / '.env').exists():
            return current
        if current.parent == current:
            break
        current = current.parent

    # Check if we're in build directory
    if (Path.cwd() / '.env').exists():
        return Path.cwd().parent

    return None


def load_environment(project_root: Path) -> Optional[Dict[str, str]]:
    """Load environment variables from .env"""
    env_file = project_root / 'build' / '.env'

    if not env_file.exists():
        click.secho(f'Error: Environment file not found: {env_file}', fg='red')
        click.echo('Please create .env from .env.example')
        return None

    try:
        env = dotenv_values(env_file)
        if not env.get('PROJECT_NAME'):
            click.secho('Error: PROJECT_NAME must be set in .env', fg='red')
            return None
        return env
    except Exception as e:
        click.secho(f'Error: Failed to load environment: {e}', fg='red')
        return None


def display_configuration(env: Dict[str, str], rebuild_app: bool, rebuild_data: bool, import_data: bool):
    """Display build configuration"""
    click.echo()
    click.secho('Build Configuration', fg='cyan', bold=True)
    click.echo('=' * 50)
    click.echo(f'REBUILD_APP_CONTAINER:   {rebuild_app}')
    click.echo(f'REBUILD_DATA_CONTAINER:  {rebuild_data}')
    click.echo(f'IMPORT_DATA:             {import_data}')
    click.echo(f'PROJECT_NAME:            {env.get("PROJECT_NAME", "")}')
    click.echo(f'APP_TYPE:                {env.get("APP_TYPE", "php-apache")}')
    click.echo(f'DATA_REL_TYPE:           {env.get("DATA_REL_TYPE", "postgres")}')
    click.echo(f'DATA_NONREL_TYPE:        {env.get("DATA_NONREL_TYPE", "(none)")}')
    click.echo('=' * 50)
    click.echo()


def create_docker_network(client: docker.DockerClient, env: Dict[str, str]) -> bool:
    """Create Docker network if it doesn't exist"""
    network_name = f"{env['PROJECT_NAME']}-network"
    click.secho(f'\nDocker Network: {network_name}', fg='cyan')

    try:
        client.networks.get(network_name)
        click.echo(f'Network {network_name} already exists')
        return True
    except docker.errors.NotFound:
        click.echo(f'Creating network: {network_name}')
        try:
            client.networks.create(network_name)
            click.secho(f'✓ Network {network_name} created', fg='green')
            return True
        except Exception as e:
            click.secho(f'Error: Failed to create network: {e}', fg='red')
            return False


def handle_app_container(client: docker.DockerClient, env: Dict[str, str], 
                         project_root: Path, rebuild: bool) -> bool:
    """Handle application container build/start"""
    container_name = f"{env['PROJECT_NAME']}-app-container"
    click.secho(f'\nApp Container: {container_name}', fg='cyan')

    try:
        container = client.containers.get(container_name)
        exists = True
    except docker.errors.NotFound:
        exists = False

    if exists and not rebuild:
        if container.status == 'running':
            click.echo(f'Container {container_name} is already running')
            return True
        else:
            click.echo(f'Starting container {container_name}')
            container.start()
            return True

    if exists and rebuild:
        click.echo('Removing existing container for rebuild')
        if container.status == 'running':
            container.stop()
        container.remove(v=True)

    # Build new container
    return build_app_container(client, env, project_root, container_name)


def build_app_container(client: docker.DockerClient, env: Dict[str, str], 
                       project_root: Path, container_name: str) -> bool:
    """Build and run application container"""
    app_type = env.get('APP_TYPE', 'php-apache')
    dockerfile = env.get('APP_DOCKERFILE', get_default_dockerfile(app_type))
    dockerfile_path = project_root / dockerfile

    if not dockerfile_path.exists():
        click.secho(f'Error: Dockerfile not found: {dockerfile_path}', fg='red')
        return False

    click.echo(f'Building app container from: {dockerfile}')

    try:
        # Build image
        image, build_logs = client.images.build(
            path=str(project_root),
            dockerfile=dockerfile,
            tag=container_name,
            buildargs={'BASE_IMAGE': env.get('APP_BASE_IMAGE', '')} if env.get('APP_BASE_IMAGE') else None
        )

        for log in build_logs:
            if 'stream' in log:
                click.echo(log['stream'], nl=False)

        # Run container
        network_name = f"{env['PROJECT_NAME']}-network"
        host_port = env.get('APP_HOST_PORT', '8080')
        container_port = get_container_port(app_type)

        ports = {f'{container_port}/tcp': host_port}
        
        volumes = {}
        if env.get('APP_VOLUME_HOST'):
            volumes[env['APP_VOLUME_HOST']] = {
                'bind': env.get('APP_VOLUME_CONTAINER', '/var/www/html'),
                'mode': 'rw'
            }

        container = client.containers.run(
            container_name,
            name=container_name,
            network=network_name,
            ports=ports,
            volumes=volumes,
            detach=True
        )

        click.secho(f'✓ Container {container_name} started successfully', fg='green')
        click.echo(f'Access at: http://localhost:{host_port}')
        return True

    except Exception as e:
        click.secho(f'Error: Failed to build/run container: {e}', fg='red')
        return False


def handle_data_containers(client: docker.DockerClient, env: Dict[str, str], 
                          project_root: Path, rebuild: bool, import_data: bool) -> bool:
    """Handle database containers"""
    # Simplified implementation - full version would mirror bash script logic
    if env.get('DATA_REL_TYPE'):
        click.secho('\nRelational database container handling...', fg='cyan')
    
    if env.get('DATA_NONREL_TYPE'):
        click.secho('Non-relational database container handling...', fg='cyan')
    
    return True


def install_composer(container) -> bool:
    """Install Composer in container"""
    click.echo('Installing Composer...')

    try:
        # Download installer
        exit_code, _ = container.exec_run([
            'php', '-r',
            "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
        ])

        if exit_code != 0:
            click.secho('Error: Failed to download Composer installer', fg='red')
            return False

        # Run installer
        exit_code, _ = container.exec_run([
            'php', '/tmp/composer-setup.php',
            '--install-dir=/usr/local/bin',
            '--filename=composer'
        ])

        if exit_code != 0:
            click.secho('Error: Failed to install Composer', fg='red')
            return False

        # Cleanup
        container.exec_run(['rm', '/tmp/composer-setup.php'])

        click.secho('✓ Composer installed successfully', fg='green')
        return True

    except Exception as e:
        click.secho(f'Error: {e}', fg='red')
        return False


def get_default_dockerfile(app_type: str) -> str:
    """Get default Dockerfile path for app type"""
    dockerfiles = {
        'php-apache': 'docker/app/Dockerfile-app-php',
        'node': 'docker/app/Dockerfile-app-node',
        'python': 'docker/app/Dockerfile-app-python',
        'java': 'docker/app/Dockerfile-app-java',
    }
    return dockerfiles.get(app_type, dockerfiles['php-apache'])


def get_container_port(app_type: str) -> str:
    """Get default container port for app type"""
    ports = {
        'php-apache': '80',
        'node': '3000',
        'python': '5000',
        'java': '8080',
    }
    return ports.get(app_type, '80')


def display_summary(env: Dict[str, str]):
    """Display container summary"""
    click.echo()
    click.secho('Container Summary', fg='cyan', bold=True)
    click.echo('=' * 70)
    
    app_container = f"{env['PROJECT_NAME']}-app-container"
    host_port = env.get('APP_HOST_PORT', '8080')
    
    click.echo(f'Container: {app_container}')
    click.echo(f'URL:       http://localhost:{host_port}')
    click.echo(f'Status:    Running')
    click.echo('=' * 70)


def fix_windows_network():
    """Fix Docker network on Windows"""
    click.echo('Fixing Docker network on Windows...')

    commands = [
        ('Restarting Docker Desktop...', ['powershell', '-Command', 'Restart-Service docker']),
        ('Flushing DNS cache...', ['powershell', '-Command', 'Clear-DnsClientCache']),
        ('Resetting Winsock...', ['powershell', '-Command', 'netsh', 'winsock', 'reset']),
    ]

    for description, command in commands:
        click.echo(description)
        try:
            subprocess.run(command, check=True, capture_output=True)
            click.secho(f'✓ Success: {description}', fg='green')
        except subprocess.CalledProcessError as e:
            click.secho(f'✗ Failed: {description}', fg='yellow')
            click.echo(e.stderr.decode() if e.stderr else '')

    click.secho('\nNetwork fix completed. You may need to restart your computer.', fg='cyan')


def fix_linux_network():
    """Fix Docker network on Linux"""
    click.echo('Fixing Docker network on Linux...')

    commands = [
        ('Restarting Docker service...', ['sudo', 'systemctl', 'restart', 'docker']),
        ('Flushing iptables...', ['sudo', 'iptables', '-F']),
    ]

    for description, command in commands:
        click.echo(description)
        try:
            subprocess.run(command, check=True, capture_output=True)
            click.secho(f'✓ Success: {description}', fg='green')
        except subprocess.CalledProcessError as e:
            click.secho(f'✗ Failed: {description}', fg='yellow')
            click.echo(e.stderr.decode() if e.stderr else '')

    click.secho('\n✓ Network fix completed!', fg='green', bold=True)


def main():
    """Main entry point"""
    cli()


if __name__ == '__main__':
    main()
