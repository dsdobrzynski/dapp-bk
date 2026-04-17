<?php

namespace Tests\Console\Commands;

use Dsdobrzynski\DockerAppBuildKit\Console\Commands\BuildCommand;
use PHPUnit\Framework\TestCase;

class BuildCommandTest extends TestCase
{
    private function makeCommand(array $env): BuildCommand
    {
        $command = new BuildCommand();
        $ref = new \ReflectionClass($command);

        $envProp = $ref->getProperty('env');
        $envProp->setAccessible(true);
        $envProp->setValue($command, $env);

        $rootProp = $ref->getProperty('projectRoot');
        $rootProp->setAccessible(true);
        $rootProp->setValue($command, '/project');

        return $command;
    }

    private function callMethod(object $object, string $method, array $args = []): mixed
    {
        $ref = new \ReflectionClass($object);
        $m = $ref->getMethod($method);
        $m->setAccessible(true);
        return $m->invokeArgs($object, $args);
    }

    // --- Dockerfile selection ---

    public function testGetDefaultDataDockerfileMysql(): void
    {
        $command = $this->makeCommand([]);
        $result = $this->callMethod($command, 'getDefaultDataDockerfile', ['mysql']);
        $this->assertSame('docker/data-rel/Dockerfile-data-mysql', $result);
    }

    public function testGetDefaultDataDockerfileMariadb(): void
    {
        $command = $this->makeCommand([]);
        $result = $this->callMethod($command, 'getDefaultDataDockerfile', ['mariadb']);
        $this->assertSame('docker/data-rel/Dockerfile-data-mariadb', $result);
    }

    public function testGetDefaultDataDockerfilePostgres(): void
    {
        $command = $this->makeCommand([]);
        $result = $this->callMethod($command, 'getDefaultDataDockerfile', ['postgres']);
        $this->assertSame('docker/data-rel/Dockerfile-data-postgres', $result);
    }

    // --- MySQL env vars ---

    public function testBuildDataRunCommandMysqlSetsCorrectEnvVars(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'          => 'testproject',
            'DATA_REL_TYPE'         => 'mysql',
            'DATA_REL_NAME'         => 'mydb',
            'DATA_REL_USERNAME'     => 'myuser',
            'DATA_REL_PASSWORD'     => 'mypass',
            'DATA_REL_HOST_PORT'    => '3306',
            'DATA_REL_CONTAINER_PORT' => '3306',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('MYSQL_DATABASE=mydb', $result);
        $this->assertContains('MYSQL_USER=myuser', $result);
        $this->assertContains('MYSQL_PASSWORD=mypass', $result);
        $this->assertContains('MYSQL_ROOT_PASSWORD=mypass', $result);
    }

    public function testBuildDataRunCommandMysqlDoesNotSetPostgresEnvVars(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'      => 'testproject',
            'DATA_REL_TYPE'     => 'mysql',
            'DATA_REL_NAME'     => 'mydb',
            'DATA_REL_USERNAME' => 'myuser',
            'DATA_REL_PASSWORD' => 'mypass',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $postgresKeys = array_filter($result, fn($v) => str_starts_with((string)$v, 'POSTGRES_'));
        $this->assertEmpty($postgresKeys, 'MySQL command must not include POSTGRES_* env vars');
    }

    // --- MariaDB env vars ---

    public function testBuildDataRunCommandMariadbUsesMysqlEnvVars(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'      => 'testproject',
            'DATA_REL_TYPE'     => 'mariadb',
            'DATA_REL_NAME'     => 'mydb',
            'DATA_REL_USERNAME' => 'myuser',
            'DATA_REL_PASSWORD' => 'mypass',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('MYSQL_DATABASE=mydb', $result);
        $this->assertContains('MYSQL_USER=myuser', $result);
        $this->assertContains('MYSQL_PASSWORD=mypass', $result);
        $this->assertContains('MYSQL_ROOT_PASSWORD=mypass', $result);
    }

    // --- Postgres env vars ---

    public function testBuildDataRunCommandPostgresSetsCorrectEnvVars(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'      => 'testproject',
            'DATA_REL_TYPE'     => 'postgres',
            'DATA_REL_NAME'     => 'mydb',
            'DATA_REL_USERNAME' => 'myuser',
            'DATA_REL_PASSWORD' => 'mypass',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('POSTGRES_DB=mydb', $result);
        $this->assertContains('POSTGRES_USER=myuser', $result);
        $this->assertContains('POSTGRES_PASSWORD=mypass', $result);

        $mysqlKeys = array_filter($result, fn($v) => str_starts_with((string)$v, 'MYSQL_'));
        $this->assertEmpty($mysqlKeys, 'Postgres command must not include MYSQL_* env vars');
    }

    // --- Default port selection ---

    public function testBuildDataRunCommandMysqlDefaultsToPort3306(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'mysql',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('3306:3306', $result);
        $this->assertNotContains('5432:5432', $result);
    }

    public function testBuildDataRunCommandMariadbDefaultsToPort3306(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'mariadb',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('3306:3306', $result);
    }

    public function testBuildDataRunCommandPostgresDefaultsToPort5432(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'postgres',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('5432:5432', $result);
    }

    // --- Volume mounts ---

    public function testBuildDataRunCommandIncludesVolumeWhenConfigured(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'                 => 'testproject',
            'DATA_REL_TYPE'                => 'mysql',
            'DATA_REL_HOST_VOLUME_PATH'    => '/host/data',
            'DATA_REL_CONTAINER_VOLUME_PATH' => '/var/lib/mysql',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('-v', $result);
        $this->assertContains('/host/data:/var/lib/mysql', $result);
    }

    public function testBuildDataRunCommandMysqlUsesDefaultContainerVolumePath(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'              => 'testproject',
            'DATA_REL_TYPE'             => 'mysql',
            'DATA_REL_HOST_VOLUME_PATH' => '/host/data',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('/host/data:/var/lib/mysql', $result);
    }

    public function testBuildDataRunCommandPostgresUsesDefaultContainerVolumePath(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'              => 'testproject',
            'DATA_REL_TYPE'             => 'postgres',
            'DATA_REL_HOST_VOLUME_PATH' => '/host/data',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertContains('/host/data:/var/lib/postgresql/data', $result);
    }

    public function testBuildDataRunCommandOmitsVolumeWhenNotConfigured(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'mysql',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', [
            'testproject-data-rel-container',
            'testproject-data-rel-image',
        ]);

        $this->assertNotContains('-v', $result);
    }

    // --- Command structure ---

    public function testBuildDataRunCommandImageIsLastElement(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'mysql',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', ['my-container', 'my-image']);

        $this->assertSame('my-image', end($result));
    }

    public function testBuildDataRunCommandIncludesContainerName(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'mysql',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', ['my-container', 'my-image']);

        $this->assertContains('my-container', $result);
    }

    public function testBuildDataRunCommandIncludesDetachedFlag(): void
    {
        $command = $this->makeCommand([
            'PROJECT_NAME'  => 'testproject',
            'DATA_REL_TYPE' => 'mysql',
        ]);

        $result = $this->callMethod($command, 'buildDataRunCommand', ['my-container', 'my-image']);

        $this->assertContains('-d', $result);
        $this->assertSame('docker', $result[0]);
        $this->assertSame('run', $result[1]);
    }
}
