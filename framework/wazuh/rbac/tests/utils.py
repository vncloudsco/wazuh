import os
from importlib import reload
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import sessionmaker


def create_memory_db(sql_file, session, test_data_path):
    with open(os.path.join(test_data_path, sql_file)) as f:
        for line in f.readlines():
            line = line.strip()
            if '* ' not in line and '/*' not in line and '*/' not in line and line != '':
                session.execute(line)


def init_db(schema, test_data_path):
    with patch('wazuh.core.common.ossec_uid'), patch('wazuh.core.common.ossec_gid'):
        with patch('wazuh.rbac.orm.create_engine', return_value=create_engine("sqlite://")):
            with patch('wazuh.rbac.orm.DATABASE_FULL_PATH', new='test_database'):
                import wazuh.rbac.orm as orm
                try:
                    orm.db_manager.connect(orm.DATABASE_FULL_PATH)
                    orm.db_manager.create_database(orm.DATABASE_FULL_PATH)
                    orm.db_manager.insert_data_from_yaml(orm.DATABASE_FULL_PATH)
                    create_memory_db(schema, orm.db_manager.sessions[orm.DATABASE_FULL_PATH], test_data_path)
                except OperationalError as e:
                    pass
                return orm
