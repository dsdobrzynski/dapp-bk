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

    # Create Docker client and check connectivity
    try:
        client = docker.from_env()
        client.ping()
        click.secho('✓ Docker is running', fg='green')
    except Exception as e:
        click.secho('✗ Unable to connect to Docker', fg='red')
        click.echo()
        click.secho('Docker does not appear to be running. Please:', fg='yellow')
        click.echo('  1. Start Docker Desktop (or Docker daemon)')
        click.echo('  2. Wait for Docker to fully start')
        click.echo('  3. Try running this command again')
        click.echo()
        click.secho('Need help? Check:', fg='cyan')
        click.echo('  • Windows: Ensure Docker Desktop is running in the system tray')
        click.echo('  • Linux: Run "sudo systemctl start docker"')
        click.echo('  • Mac: Ensure Docker Desktop is running in the menu bar')
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
        if (current / '.env').exists():
            return current
        if (current / 'build' / '.env').exists():
            return current
        if current.parent == current:
            break
        current = current.parent

    return None


def load_environment(project_root: Path) -> Optional[Dict[str, str]]:
    """Load environment variables from .env"""
    env_file = project_root / '.env'
    if not env_file.exists():
        env_file = project_root / 'build' / '.env'

    if not env_file.exists():
        click.secho('Error: Environment file not found in project root or build/', fg='red')
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
            buildargs={
                **({'BASE_IMAGE': env['APP_BASE_IMAGE']}           if env.get('APP_BASE_IMAGE')   else {}),
                **({'DATA_REL_TYPE': env['DATA_REL_TYPE']}         if env.get('DATA_REL_TYPE')    else {}),
                **({'DATA_NONREL_TYPE': env['DATA_NONREL_TYPE']}   if env.get('DATA_NONREL_TYPE') else {}),
            } or None
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
        if env.get('APP_HOST_VOLUME_PATH'):
            volumes[env['APP_HOST_VOLUME_PATH']] = {
                'bind': env.get('APP_CONTAINER_VOLUME_PATH', '/var/www/html'),
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
    if env.get('DATA_REL_TYPE'):
        if not handle_relational_database(client, env, project_root, rebuild):
            return False

    if env.get('DATA_NONREL_TYPE'):
        if not handle_non_relational_database(client, env, project_root, rebuild):
            return False

    return True


def handle_relational_database(client: docker.DockerClient, env: Dict[str, str],
                               project_root: Path, rebuild: bool) -> bool:
    """Handle relational database container"""
    container_name = f"{env['PROJECT_NAME']}-data-rel-container"
    click.secho(f'\nRelational Database: {container_name}', fg='cyan')

    container = None
    exists = False
    try:
        container = client.containers.get(container_name)
        exists = True
    except docker.errors.NotFound:
        pass

    if exists and not rebuild:
        if container.status == 'running':
            click.echo(f'Container {container_name} is already running')
            return True
        click.echo(f'Starting container {container_name}')
        container.start()
        return True

    if exists and rebuild:
        click.echo('Removing existing container for rebuild')
        if container.status == 'running':
            container.stop()
        container.remove(v=True)

    return build_data_container(client, env, project_root, container_name, 'rel')


def handle_non_relational_database(client: docker.DockerClient, env: Dict[str, str],
                                   project_root: Path, rebuild: bool) -> bool:
    """Handle non-relational database container"""
    container_name = f"{env['PROJECT_NAME']}-data-nonrel-container"
    click.secho(f'\nNon-Relational Database: {container_name}', fg='cyan')

    container = None
    exists = False
    try:
        container = client.containers.get(container_name)
        exists = True
    except docker.errors.NotFound:
        pass

    if exists and not rebuild:
        if container.status == 'running':
            click.echo(f'Container {container_name} is already running')
            return True
        click.echo(f'Starting container {container_name}')
        container.start()
        return True

    if exists and rebuild:
        click.echo('Removing existing container for rebuild')
        if container.status == 'running':
            container.stop()
        container.remove(v=True)

    return build_data_container(client, env, project_root, container_name, 'nonrel')


def build_data_container(client: docker.DockerClient, env: Dict[str, str],
                        project_root: Path, container_name: str, kind: str) -> bool:
    """Build and run a data container"""
    is_rel = kind == 'rel'
    data_type = env.get('DATA_REL_TYPE', 'postgres') if is_rel else env.get('DATA_NONREL_TYPE', '')
    dockerfile_key = 'DATA_REL_DOCKERFILE' if is_rel else 'DATA_NONREL_DOCKERFILE'
    dockerfile = env.get(dockerfile_key) or get_default_data_dockerfile(data_type)
    dockerfile_path = project_root / dockerfile

    if not dockerfile_path.exists():
        click.secho(f'Error: Dockerfile not found: {dockerfile_path}', fg='red')
        return False

    click.echo(f'Building data container from: {dockerfile}')

    try:
        prefix = 'data-rel' if is_rel else 'data-nonrel'
        image_name = f"{env['PROJECT_NAME']}-{prefix}-image"

        image, build_logs = client.images.build(
            path=str(project_root),
            dockerfile=dockerfile,
            tag=image_name,
        )

        for log in build_logs:
            if 'stream' in log:
                click.echo(log['stream'], nl=False)

        return run_data_container(client, env, container_name, image_name, kind)

    except Exception as e:
        click.secho(f'Error: Failed to build data container: {e}', fg='red')
        return False


def run_data_container(client: docker.DockerClient, env: Dict[str, str],
                      container_name: str, image_name: str, kind: str) -> bool:
    """Run a data container with type-specific configuration"""
    is_rel = kind == 'rel'
    data_type = env.get('DATA_REL_TYPE', 'postgres') if is_rel else env.get('DATA_NONREL_TYPE', '')
    host_port_key = 'DATA_REL_HOST_PORT' if is_rel else 'DATA_NONREL_HOST_PORT'
    container_port_key = 'DATA_REL_CONTAINER_PORT' if is_rel else 'DATA_NONREL_CONTAINER_PORT'
    host_port = env.get(host_port_key) or get_default_data_port(data_type)
    container_port = env.get(container_port_key) or get_default_data_port(data_type)
    network_name = f"{env['PROJECT_NAME']}-network"

    click.echo(f'Starting container: {container_name} on port {host_port}')

    try:
        env_vars = build_data_env_vars(env, data_type, is_rel)
        ports = {f'{container_port}/tcp': host_port}
        volumes = {}

        host_vol_key = 'DATA_REL_HOST_VOLUME_PATH' if is_rel else 'DATA_NONREL_HOST_VOLUME_PATH'
        container_vol_key = 'DATA_REL_CONTAINER_VOLUME_PATH' if is_rel else 'DATA_NONREL_CONTAINER_VOLUME_PATH'
        if env.get(host_vol_key):
            volumes[env[host_vol_key]] = {
                'bind': env.get(container_vol_key) or get_default_data_volume(data_type),
                'mode': 'rw',
            }

        client.containers.run(
            image_name,
            name=container_name,
            network=network_name,
            environment=env_vars,
            ports=ports,
            volumes=volumes,
            detach=True,
        )

        click.secho('✓ Data container started successfully', fg='green')
        return True

    except Exception as e:
        click.secho(f'Error: Failed to run data container: {e}', fg='red')
        return False


def build_data_env_vars(env: Dict[str, str], data_type: str, is_rel: bool) -> Dict[str, str]:
    """Build environment variables dict for a data container"""
    prefix = 'DATA_REL' if is_rel else 'DATA_NONREL'
    db_name = env.get(f'{prefix}_NAME', 'appdb')
    db_user = env.get(f'{prefix}_USERNAME', 'appuser')
    db_password = env.get(f'{prefix}_PASSWORD', 'apppass')

    if data_type in ('mysql', 'mariadb'):
        return {
            'MYSQL_DATABASE': db_name,
            'MYSQL_USER': db_user,
            'MYSQL_PASSWORD': db_password,
            'MYSQL_ROOT_PASSWORD': db_password,
        }
    if data_type == 'mongodb':
        return {
            'MONGO_INITDB_DATABASE': db_name,
            'MONGO_INITDB_ROOT_USERNAME': db_user,
            'MONGO_INITDB_ROOT_PASSWORD': db_password,
        }
    if data_type == 'neo4j':
        return {'NEO4J_AUTH': f'{db_user}/{db_password}'}
    return {
        'POSTGRES_DB': db_name,
        'POSTGRES_USER': db_user,
        'POSTGRES_PASSWORD': db_password,
    }


def get_default_data_dockerfile(data_type: str) -> str:
    """Get default Dockerfile path for data type"""
    dockerfiles = {
        'mysql':    'docker/data-rel/Dockerfile-data-mysql',
        'mariadb':  'docker/data-rel/Dockerfile-data-mariadb',
        'postgres': 'docker/data-rel/Dockerfile-data-postgres',
        'mongodb':  'docker/data-nonrel/Dockerfile-data-mongodb',
        'neo4j':    'docker/data-nonrel/Dockerfile-data-neo4j',
    }
    return dockerfiles.get(data_type, f'docker/data-rel/Dockerfile-data-{data_type}')


def get_default_data_port(data_type: str) -> str:
    """Get default port for database type"""
    if data_type in ('mysql', 'mariadb'):
        return '3306'
    if data_type == 'neo4j':
        return '7687'
    if data_type == 'mongodb':
        return '27017'
    return '5432'


def get_default_data_volume(data_type: str) -> str:
    """Get default container volume path for data type"""
    volume_paths = {
        'postgres': '/var/lib/postgresql/data',
        'mongodb':  '/data/db',
        'neo4j':    '/data',
    }
    return volume_paths.get(data_type, '/var/lib/mysql')


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
