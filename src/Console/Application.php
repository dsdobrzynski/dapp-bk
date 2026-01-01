<?php

namespace Dsdobrzynski\DockerAppBuildKit\Console;

use Symfony\Component\Console\Application as BaseApplication;

class Application extends BaseApplication
{
    const VERSION = '1.0.0';

    public function __construct()
    {
        parent::__construct('Docker App Build Kit', self::VERSION);

        $this->add(new Commands\BuildCommand());
        $this->add(new Commands\ComposerInstallCommand());
        $this->add(new Commands\NetworkFixCommand());
    }
}
