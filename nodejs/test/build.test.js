import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildDataContainerConfig,
  buildDataEnvVars,
  getDefaultDataDockerfile,
} from '../commands/build.js';

const relEnv = {
  PROJECT_NAME: 'testproject',
  DATA_REL_NAME: 'mydb',
  DATA_REL_USERNAME: 'myuser',
  DATA_REL_PASSWORD: 'mypass',
};

const nonRelEnv = {
  PROJECT_NAME: 'testproject',
  DATA_NONREL_NAME: 'mydb',
  DATA_NONREL_USERNAME: 'myuser',
  DATA_NONREL_PASSWORD: 'mypass',
};

// --- Dockerfile selection ---

describe('getDefaultDataDockerfile', () => {
  it('mysql', () => assert.equal(getDefaultDataDockerfile('mysql'), 'docker/data-rel/Dockerfile-data-mysql'));
  it('mariadb', () => assert.equal(getDefaultDataDockerfile('mariadb'), 'docker/data-rel/Dockerfile-data-mariadb'));
  it('postgres', () => assert.equal(getDefaultDataDockerfile('postgres'), 'docker/data-rel/Dockerfile-data-postgres'));
  it('mongodb', () => assert.equal(getDefaultDataDockerfile('mongodb'), 'docker/data-nonrel/Dockerfile-data-mongodb'));
  it('neo4j', () => assert.equal(getDefaultDataDockerfile('neo4j'), 'docker/data-nonrel/Dockerfile-data-neo4j'));
});

// --- Env vars ---

describe('buildDataEnvVars - mysql', () => {
  it('sets MYSQL_* vars', () => {
    const vars = buildDataEnvVars(relEnv, 'mysql', true);
    assert.ok(vars.includes('MYSQL_DATABASE=mydb'));
    assert.ok(vars.includes('MYSQL_USER=myuser'));
    assert.ok(vars.includes('MYSQL_PASSWORD=mypass'));
    assert.ok(vars.includes('MYSQL_ROOT_PASSWORD=mypass'));
  });

  it('sets no POSTGRES_* vars', () => {
    const vars = buildDataEnvVars(relEnv, 'mysql', true);
    assert.ok(!vars.some(v => v.startsWith('POSTGRES_')));
  });
});

describe('buildDataEnvVars - mariadb', () => {
  it('uses MYSQL_* vars', () => {
    const vars = buildDataEnvVars(relEnv, 'mariadb', true);
    assert.ok(vars.includes('MYSQL_DATABASE=mydb'));
    assert.ok(vars.includes('MYSQL_ROOT_PASSWORD=mypass'));
  });
});

describe('buildDataEnvVars - postgres', () => {
  it('sets POSTGRES_* vars', () => {
    const vars = buildDataEnvVars(relEnv, 'postgres', true);
    assert.ok(vars.includes('POSTGRES_DB=mydb'));
    assert.ok(vars.includes('POSTGRES_USER=myuser'));
    assert.ok(vars.includes('POSTGRES_PASSWORD=mypass'));
  });

  it('sets no MYSQL_* vars', () => {
    const vars = buildDataEnvVars(relEnv, 'postgres', true);
    assert.ok(!vars.some(v => v.startsWith('MYSQL_')));
  });
});

describe('buildDataEnvVars - mongodb', () => {
  it('sets MONGO_INITDB_* vars', () => {
    const vars = buildDataEnvVars(nonRelEnv, 'mongodb', false);
    assert.ok(vars.includes('MONGO_INITDB_DATABASE=mydb'));
    assert.ok(vars.includes('MONGO_INITDB_ROOT_USERNAME=myuser'));
    assert.ok(vars.includes('MONGO_INITDB_ROOT_PASSWORD=mypass'));
  });
});

describe('buildDataEnvVars - neo4j', () => {
  it('sets NEO4J_AUTH', () => {
    const vars = buildDataEnvVars(nonRelEnv, 'neo4j', false);
    assert.ok(vars.includes('NEO4J_AUTH=myuser/mypass'));
  });
});

describe('buildDataEnvVars - defaults', () => {
  it('falls back to appdb/appuser/apppass when credentials missing', () => {
    const vars = buildDataEnvVars({ PROJECT_NAME: 'p' }, 'mysql', true);
    assert.ok(vars.includes('MYSQL_DATABASE=appdb'));
    assert.ok(vars.includes('MYSQL_USER=appuser'));
    assert.ok(vars.includes('MYSQL_PASSWORD=apppass'));
  });
});

// --- Port defaults ---

describe('buildDataContainerConfig - port defaults', () => {
  it('mysql defaults to 3306', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'mysql' }, 'c', 'img', 'rel');
    assert.ok('3306/tcp' in cfg.HostConfig.PortBindings);
    assert.equal(cfg.HostConfig.PortBindings['3306/tcp'][0].HostPort, '3306');
  });

  it('mariadb defaults to 3306', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'mariadb' }, 'c', 'img', 'rel');
    assert.ok('3306/tcp' in cfg.HostConfig.PortBindings);
  });

  it('postgres defaults to 5432', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'postgres' }, 'c', 'img', 'rel');
    assert.ok('5432/tcp' in cfg.HostConfig.PortBindings);
    assert.equal(cfg.HostConfig.PortBindings['5432/tcp'][0].HostPort, '5432');
  });

  it('honours custom host port from env', () => {
    const cfg = buildDataContainerConfig(
      { ...relEnv, DATA_REL_TYPE: 'mysql', DATA_REL_HOST_PORT: '13306', DATA_REL_CONTAINER_PORT: '3306' },
      'c', 'img', 'rel'
    );
    assert.equal(cfg.HostConfig.PortBindings['3306/tcp'][0].HostPort, '13306');
  });
});

// --- Volume mounts ---

describe('buildDataContainerConfig - volumes', () => {
  it('adds Binds when host volume configured', () => {
    const cfg = buildDataContainerConfig(
      { ...relEnv, DATA_REL_TYPE: 'mysql', DATA_REL_HOST_VOLUME_PATH: '/host/data', DATA_REL_CONTAINER_VOLUME_PATH: '/var/lib/mysql' },
      'c', 'img', 'rel'
    );
    assert.ok(Array.isArray(cfg.HostConfig.Binds));
    assert.ok(cfg.HostConfig.Binds[0].includes('/host/data:/var/lib/mysql'));
  });

  it('uses default mysql volume path when container path omitted', () => {
    const cfg = buildDataContainerConfig(
      { ...relEnv, DATA_REL_TYPE: 'mysql', DATA_REL_HOST_VOLUME_PATH: '/host/data' },
      'c', 'img', 'rel'
    );
    assert.ok(cfg.HostConfig.Binds[0].includes('/host/data:/var/lib/mysql'));
  });

  it('uses default postgres volume path when container path omitted', () => {
    const cfg = buildDataContainerConfig(
      { ...relEnv, DATA_REL_TYPE: 'postgres', DATA_REL_HOST_VOLUME_PATH: '/host/data' },
      'c', 'img', 'rel'
    );
    assert.ok(cfg.HostConfig.Binds[0].includes('/host/data:/var/lib/postgresql/data'));
  });

  it('omits Binds when no volume configured', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'mysql' }, 'c', 'img', 'rel');
    assert.equal(cfg.HostConfig.Binds, undefined);
  });
});

// --- Container config structure ---

describe('buildDataContainerConfig - structure', () => {
  it('sets name and image', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'mysql' }, 'my-container', 'my-image', 'rel');
    assert.equal(cfg.name, 'my-container');
    assert.equal(cfg.Image, 'my-image');
  });

  it('sets project network', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'mysql' }, 'c', 'img', 'rel');
    assert.equal(cfg.HostConfig.NetworkMode, 'testproject-network');
  });

  it('exposes container port', () => {
    const cfg = buildDataContainerConfig({ ...relEnv, DATA_REL_TYPE: 'mysql' }, 'c', 'img', 'rel');
    assert.ok('3306/tcp' in cfg.ExposedPorts);
  });
});
