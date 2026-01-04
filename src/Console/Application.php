<?php

namespace Dsdobrzynski\DockerAppBuildKit\Console;

use Symfony\Component\Console\Application as BaseApplication;
use Dsdobrzynski\DockerAppBuildKit\Console\Commands\BuildCommand;
use Dsdobrzynski\DockerAppBuildKit\Console\Commands\ComposerInstallCommand;
use Dsdobrzynski\DockerAppBuildKit\Console\Commands\NetworkFixCommand;

/**
 * @method \Symfony\Component\Console\Command\Command addCommand(\Symfony\Component\Console\Command\Command $command)
 */
class Application extends BaseApplication
{
    const VERSION = '1.0.0';

    public function __construct()
    {
        parent::__construct('Docker App Build Kit', self::VERSION);

        $this->addCommand(new BuildCommand());
        $this->addCommand(new ComposerInstallCommand());
        $this->addCommand(new NetworkFixCommand());
    }
}
