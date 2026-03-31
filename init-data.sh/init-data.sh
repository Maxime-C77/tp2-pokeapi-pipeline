#!/bin/bash
# ============================================================
# Script d'initialisation PostgreSQL
# Inspiré de https://github.com/n8n-io/n8n-hosting/blob/main/docker-compose/withPostgres/init-data.sh
# Crée un utilisateur non-root pour n8n et l'application
# ============================================================

set -e;

if [ -n "${POSTGRES_NON_ROOT_USER:-}" ] && [ -n "${POSTGRES_NON_ROOT_PASSWORD:-}" ]; then
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE USER ${POSTGRES_NON_ROOT_USER} WITH PASSWORD '${POSTGRES_NON_ROOT_PASSWORD}';
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_NON_ROOT_USER};
		GRANT ALL ON SCHEMA public TO ${POSTGRES_NON_ROOT_USER};
		ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${POSTGRES_NON_ROOT_USER};
		ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${POSTGRES_NON_ROOT_USER};
	EOSQL
else
	echo "SETUP INFO: No Environment variables given!"
fi
