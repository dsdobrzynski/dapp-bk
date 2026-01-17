<?php

namespace Dsdobrzynski\DockerAppBuildKit\Console\Commands;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;
use Symfony\Component\Dotenv\Dotenv;
use Symfony\Component\Process\Process;

class ComposerInstallCommand extends Command
{
    protected static $defaultName = 'composer:install';
    protected static $defaultDescription = 'Install Composer dependencies in the app container';

    private $env = [];

    protected function configure(): void
    {
        $this
            ->setName('composer:install')
            ->setDescription(self::$defaultDescription)
            ->setHelp('This command installs PHP dependencies using Composer in the running app container');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        $io->title('App Container Composer Install');

        // Find project root
        $projectRoot = $this->findProjectRoot();
        if (!$projectRoot) {
            $io->error('Could not find project root with .env file');
            return Command::FAILURE;
        }

        // Load environment to get project name
        if (!$this->loadEnvironment($io, $projectRoot)) {
            return Command::FAILURE;
        }

        // Build container name dynamically from PROJECT_NAME
        $appContainerName = $this->env['PROJECT_NAME'] . '-app-container';
        $io->text("Container: $appContainerName");

        // Check if container is running
        $process = new Process(['docker', 'inspect', '-f', '{{.State.Status}}', $appContainerName]);
        $process->run();

        if (!$process->isSuccessful()) {
            $io->error("Container '$appContainerName' not found");
            $io->note('Run the build command first to create containers');
            return Command::FAILURE;
        }

        $status = trim($process->getOutput());
        if ($status !== 'running') {
            $io->error("Container '$appContainerName' is not running (status: $status)");
            return Command::FAILURE;
        }

        $io->success('Container is running');

        // Determine project root inside container from .env or default
        $containerVolumePath = $this->env['APP_CONTAINER_VOLUME_PATH'] ?? '/var/www/html';
        $io->text("Project root in container: $containerVolumePath");

        // Check if composer.json exists
        $io->text('Checking for composer.json...');
        $process = new Process([
            'docker', 'exec', $appContainerName,
            'test', '-f', "$containerVolumePath/composer.json"
        ]);
        $process->run();

        if (!$process->isSuccessful()) {
            $io->warning("No composer.json found in $containerVolumePath");
            $io->note('Skipping Composer install');
            return Command::SUCCESS;
        }

        $io->success('Found composer.json');

        // Check if Composer is installed
        $io->text('Checking for Composer...');
        $process = new Process(['docker', 'exec', $appContainerName, 'which', 'composer']);
        $process->run();

        if (!$process->isSuccessful()) {
            $io->text('Composer not found, installing...');
            if (!$this->installComposer($io, $appContainerName)) {
                return Command::FAILURE;
            }
        } else {
            $io->success('Composer is installed');
        }

        // Run composer install
        $io->text('Running composer install...');
        $process = new Process([
            'docker', 'exec', '-w', $containerVolumePath, $appContainerName,
            'composer', 'install', '--no-interaction', '--optimize-autoloader'
        ]);
        $process->setTimeout(600); // 10 minutes
        $process->run(function ($type, $buffer) use ($io) {
            $io->write($buffer);
        });

        if (!$process->isSuccessful()) {
            $io->error('Composer install failed');
            return Command::FAILURE;
        }

        $io->success('Composer install completed successfully!');
        return Command::SUCCESS;
    }

    private function loadEnvironment(SymfonyStyle $io, string $projectRoot): bool
    {
        $envFile = $projectRoot . '/.env';
        
        if (!file_exists($envFile)) {
            $io->error("Environment file not found: $envFile");
            return false;
        }

        try {
            // Read and filter .env file to only include valid environment variable names
            $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            $filteredLines = [];
            
            foreach ($lines as $line) {
                $line = trim($line);
                // Skip comments and empty lines
                if (empty($line) || $line[0] === '#') {
                    continue;
                }
                // Only include lines with valid env var names (no dots)
                if (preg_match('/^[A-Z_][A-Z0-9_]*=/', $line)) {
                    $filteredLines[] = $line;
                }
            }
            
            $dotenv = new Dotenv();
            $this->env = $dotenv->parse(implode("\n", $filteredLines));

            if (empty($this->env['PROJECT_NAME'])) {
                $io->error('PROJECT_NAME must be set in .env');
                return false;
            }

            return true;
        } catch (\Exception $e) {
            $io->error('Failed to load environment: ' . $e->getMessage());
            return false;
        }
    }

    private function findProjectRoot(): ?string
    {
        $current = getcwd();
        $maxLevels = 5;

        for ($i = 0; $i < $maxLevels; $i++) {
            if (file_exists($current . '/.env')) {
                return $current;
            }
            $parent = dirname($current);
            if ($parent === $current) {
                break;
            }
            $current = $parent;
        }

        return null;
    }

    private function installComposer(SymfonyStyle $io, string $containerName): bool
    {
        $io->text('Installing Composer...');

        // Download installer
        $process = new Process([
            'docker', 'exec', $containerName,
            'php', '-r',
            "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
        ]);
        $process->run();

        if (!$process->isSuccessful()) {
            $io->error('Failed to download Composer installer');
            return false;
        }

        // Run installer
        $process = new Process([
            'docker', 'exec', $containerName,
            'php', '/tmp/composer-setup.php',
            '--install-dir=/usr/local/bin',
            '--filename=composer'
        ]);
        $process->run();

        if (!$process->isSuccessful()) {
            $io->error('Failed to install Composer');
            return false;
        }

        // Cleanup
        $process = new Process([
            'docker', 'exec', $containerName,
            'rm', '/tmp/composer-setup.php'
        ]);
        $process->run();

        $io->success('Composer installed successfully');
        return true;
    }
}
