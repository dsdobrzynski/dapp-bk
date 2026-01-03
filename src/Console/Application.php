<?php

namespace Dsdobrzynski\DockerAppBuildKit\Console;

use Symfony\Component\Console\Application as BaseApplication;
use Dsdobrzynski\DockerAppBuildKit\Console\Commands\BuildCommand;
use Dsdobrzynski\DockerAppBuildKit\Console\Commands\ComposerInstallCommand;
use Dsdobrzynski\DockerAppBuildKit\Console\Commands\NetworkFixCommand;

class Application extends BaseApplication
{
    const VERSION = '1.0.0';

    public function __construct()
    {
        parent::__construct('Docker App Build Kit', self::VERSION);

        $this->add(new BuildCommand());
        $this->add(new ComposerInstallCommand());
        $this->add(new NetworkFixCommand());
    }
}
