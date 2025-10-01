#!/bin/sh
set -e

# These are expected to be provided by the overlay Secret via the Pod env.
: "${POSTGRES_DB:?POSTGRES_DB not set}"
: "${POSTGRES_USER:?POSTGRES_USER not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD not set}"

echo "Ensuring app role and database exist: $POSTGRES_DB / $POSTGRES_USER"

# Ensure role exists and set password without using DO/transactions to avoid quoting pitfalls.
if ! psql -tA --username "postgres" -c "SELECT 1 FROM pg_roles WHERE rolname = '${POSTGRES_USER}'" | grep -q '^1$'; then
  psql --username "postgres" -c "CREATE USER \"${POSTGRES_USER}\" WITH PASSWORD '${POSTGRES_PASSWORD}'"
else
  psql --username "postgres" -c "ALTER USER \"${POSTGRES_USER}\" WITH PASSWORD '${POSTGRES_PASSWORD}'"
fi

# CREATE DATABASE cannot run inside a transaction/DO block. Check-and-create in separate commands.
if ! psql -tA --username "postgres" -c "SELECT 1 FROM pg_database WHERE datname = '${POSTGRES_DB}'" | grep -q '^1$'; then
  psql --username "postgres" -c "CREATE DATABASE \"${POSTGRES_DB}\""
fi

# Ownership and schema privileges so the app can create tables in public
psql --username "postgres" -c "ALTER DATABASE \"${POSTGRES_DB}\" OWNER TO \"${POSTGRES_USER}\""
psql --username "postgres" -d "${POSTGRES_DB}" -c "ALTER SCHEMA public OWNER TO \"${POSTGRES_USER}\""
psql --username "postgres" -d "${POSTGRES_DB}" -c "GRANT USAGE, CREATE ON SCHEMA public TO \"${POSTGRES_USER}\""

# Grant database-level privileges (CONNECT, CREATE, TEMP)
psql --username "postgres" -c "GRANT ALL PRIVILEGES ON DATABASE \"${POSTGRES_DB}\" TO \"${POSTGRES_USER}\""
