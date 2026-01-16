#!/bin/bash
set -e

# TODO[VCC-012c]: Create the database and the user for Grafana

# Create the database and the user for Grafana
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER {{ grafana_db_user }} WITH PASSWORD '{{ grafana_db_password }}';
    CREATE DATABASE {{ grafana_db }} OWNER {{ grafana_db_user }};
    GRANT ALL PRIVILEGES ON DATABASE {{ grafana_db }} TO {{ grafana_db_user }};
EOSQL