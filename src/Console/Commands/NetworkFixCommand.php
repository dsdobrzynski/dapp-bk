<?php

namespace Dsdobrzynski\DockerAppBuildKit\Console\Commands;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;
use Symfony\Component\Process\Process;

class NetworkFixCommand extends Command
{
    protected static $defaultName = 'network:fix';
    protected static $defaultDescription = 'Fix Docker network issues';

    protected function configure(): void
    {
        $this
            ->setDescription(self::$defaultDescription)
            ->setHelp('This command fixes common Docker network connectivity issues');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $io = new SymfonyStyle($input, $output);
        $io->title('Docker Network Fix');

        if (PHP_OS_FAMILY === 'Windows') {
            return $this->fixWindowsNetwork($io);
        } else {
            return $this->fixLinuxNetwork($io);
        }
    }

    private function fixWindowsNetwork(SymfonyStyle $io): int
    {
        $io->text('Fixing Docker network on Windows...');

        $commands = [
            'Restarting Docker Desktop...' => ['powershell', '-Command', 'Restart-Service docker'],
            'Flushing DNS cache...' => ['powershell', '-Command', 'Clear-DnsClientCache'],
            'Resetting Winsock...' => ['powershell', '-Command', 'netsh', 'winsock', 'reset'],
        ];

        foreach ($commands as $description => $command) {
            $io->text($description);
            $process = new Process($command);
            $process->run();

            if (!$process->isSuccessful()) {
                $io->warning("Failed: $description");
                $io->text($process->getErrorOutput());
            } else {
                $io->success("Success: $description");
            }
        }

        $io->info('Network fix completed. You may need to restart your computer for all changes to take effect.');
        return Command::SUCCESS;
    }

    private function fixLinuxNetwork(SymfonyStyle $io): int
    {
        $io->text('Fixing Docker network on Linux...');

        $commands = [
            'Restarting Docker service...' => ['sudo', 'systemctl', 'restart', 'docker'],
            'Flushing iptables...' => ['sudo', 'iptables', '-F'],
        ];

        foreach ($commands as $description => $command) {
            $io->text($description);
            $process = new Process($command);
            $process->run();

            if (!$process->isSuccessful()) {
                $io->warning("Failed: $description");
                $io->text($process->getErrorOutput());
            } else {
                $io->success("Success: $description");
            }
        }

        $io->success('Network fix completed!');
        return Command::SUCCESS;
    }
}
