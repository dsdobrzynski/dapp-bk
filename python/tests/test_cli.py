import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from hig_docker_build_kit.cli import (
    build_data_env_vars,
    get_default_data_dockerfile,
    get_default_data_port,
    get_default_data_volume,
)

REL_ENV = {
    'DATA_REL_NAME': 'mydb',
    'DATA_REL_USERNAME': 'myuser',
    'DATA_REL_PASSWORD': 'mypass',
}

NONREL_ENV = {
    'DATA_NONREL_NAME': 'mydb',
    'DATA_NONREL_USERNAME': 'myuser',
    'DATA_NONREL_PASSWORD': 'mypass',
}


# --- Dockerfile selection ---

class TestGetDefaultDataDockerfile:
    def test_mysql(self):
        assert get_default_data_dockerfile('mysql') == 'docker/data-rel/Dockerfile-data-mysql'

    def test_mariadb(self):
        assert get_default_data_dockerfile('mariadb') == 'docker/data-rel/Dockerfile-data-mariadb'

    def test_postgres(self):
        assert get_default_data_dockerfile('postgres') == 'docker/data-rel/Dockerfile-data-postgres'

    def test_mongodb(self):
        assert get_default_data_dockerfile('mongodb') == 'docker/data-nonrel/Dockerfile-data-mongodb'

    def test_neo4j(self):
        assert get_default_data_dockerfile('neo4j') == 'docker/data-nonrel/Dockerfile-data-neo4j'


# --- Default ports ---

class TestGetDefaultDataPort:
    def test_mysql_returns_3306(self):
        assert get_default_data_port('mysql') == '3306'

    def test_mariadb_returns_3306(self):
        assert get_default_data_port('mariadb') == '3306'

    def test_postgres_returns_5432(self):
        assert get_default_data_port('postgres') == '5432'

    def test_mongodb_returns_27017(self):
        assert get_default_data_port('mongodb') == '27017'

    def test_neo4j_returns_7687(self):
        assert get_default_data_port('neo4j') == '7687'


# --- Default volume paths ---

class TestGetDefaultDataVolume:
    def test_mysql(self):
        assert get_default_data_volume('mysql') == '/var/lib/mysql'

    def test_mariadb(self):
        assert get_default_data_volume('mariadb') == '/var/lib/mysql'

    def test_postgres(self):
        assert get_default_data_volume('postgres') == '/var/lib/postgresql/data'

    def test_mongodb(self):
        assert get_default_data_volume('mongodb') == '/data/db'

    def test_neo4j(self):
        assert get_default_data_volume('neo4j') == '/data'


# --- Env vars ---

class TestBuildDataEnvVarsMysql:
    def test_sets_mysql_vars(self):
        result = build_data_env_vars(REL_ENV, 'mysql', True)
        assert result['MYSQL_DATABASE'] == 'mydb'
        assert result['MYSQL_USER'] == 'myuser'
        assert result['MYSQL_PASSWORD'] == 'mypass'
        assert result['MYSQL_ROOT_PASSWORD'] == 'mypass'

    def test_does_not_set_postgres_vars(self):
        result = build_data_env_vars(REL_ENV, 'mysql', True)
        assert 'POSTGRES_DB' not in result

    def test_root_password_matches_user_password(self):
        result = build_data_env_vars(REL_ENV, 'mysql', True)
        assert result['MYSQL_ROOT_PASSWORD'] == result['MYSQL_PASSWORD']


class TestBuildDataEnvVarsMariadb:
    def test_uses_mysql_vars(self):
        result = build_data_env_vars(REL_ENV, 'mariadb', True)
        assert result['MYSQL_DATABASE'] == 'mydb'
        assert result['MYSQL_ROOT_PASSWORD'] == 'mypass'

    def test_does_not_set_postgres_vars(self):
        result = build_data_env_vars(REL_ENV, 'mariadb', True)
        assert 'POSTGRES_DB' not in result


class TestBuildDataEnvVarsPostgres:
    def test_sets_postgres_vars(self):
        result = build_data_env_vars(REL_ENV, 'postgres', True)
        assert result['POSTGRES_DB'] == 'mydb'
        assert result['POSTGRES_USER'] == 'myuser'
        assert result['POSTGRES_PASSWORD'] == 'mypass'

    def test_does_not_set_mysql_vars(self):
        result = build_data_env_vars(REL_ENV, 'postgres', True)
        assert 'MYSQL_DATABASE' not in result


class TestBuildDataEnvVarsMongodb:
    def test_sets_mongo_vars(self):
        result = build_data_env_vars(NONREL_ENV, 'mongodb', False)
        assert result['MONGO_INITDB_DATABASE'] == 'mydb'
        assert result['MONGO_INITDB_ROOT_USERNAME'] == 'myuser'
        assert result['MONGO_INITDB_ROOT_PASSWORD'] == 'mypass'


class TestBuildDataEnvVarsNeo4j:
    def test_sets_auth_var(self):
        result = build_data_env_vars(NONREL_ENV, 'neo4j', False)
        assert result['NEO4J_AUTH'] == 'myuser/mypass'


class TestBuildDataEnvVarsDefaults:
    def test_falls_back_when_credentials_missing(self):
        result = build_data_env_vars({}, 'mysql', True)
        assert result['MYSQL_DATABASE'] == 'appdb'
        assert result['MYSQL_USER'] == 'appuser'
        assert result['MYSQL_PASSWORD'] == 'apppass'

    def test_postgres_defaults(self):
        result = build_data_env_vars({}, 'postgres', True)
        assert result['POSTGRES_DB'] == 'appdb'
        assert result['POSTGRES_USER'] == 'appuser'
        assert result['POSTGRES_PASSWORD'] == 'apppass'
