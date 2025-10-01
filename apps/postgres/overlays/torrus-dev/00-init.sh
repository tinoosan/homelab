#!/bin/sh
set -e

# These are expected to be provided by the overlay Secret via the Pod env.
: "${APP_DB:?APP_DB not set}"
: "${APP_USER:?APP_USER not set}"
: "${APP_PASSWORD:?APP_PASSWORD not set}"

echo "Ensuring app role and database exist: $APP_DB / $APP_USER"

# Ensure role exists and set password without using DO/transactions to avoid quoting pitfalls.
if ! psql -tA --username "postgres" -c "SELECT 1 FROM pg_roles WHERE rolname = '${APP_USER}'" | grep -q '^1$'; then
  psql --username "postgres" -c "CREATE USER \"${APP_USER}\" WITH PASSWORD '${APP_PASSWORD}'"
else
  psql --username "postgres" -c "ALTER USER \"${APP_USER}\" WITH PASSWORD '${APP_PASSWORD}'"
fi

# CREATE DATABASE cannot run inside a transaction/DO block. Check-and-create in separate commands.
if ! psql -tA --username "postgres" -c "SELECT 1 FROM pg_database WHERE datname = '${APP_DB}'" | grep -q '^1$'; then
  psql --username "postgres" -c "CREATE DATABASE \"${APP_DB}\""
fi

# Ownership and schema privileges so the app can create tables in public
psql --username "postgres" -c "ALTER DATABASE \"${APP_DB}\" OWNER TO \"${APP_USER}\""
psql --username "postgres" -d "${APP_DB}" -c "ALTER SCHEMA public OWNER TO \"${APP_USER}\""
psql --username "postgres" -d "${APP_DB}" -c "GRANT USAGE, CREATE ON SCHEMA public TO \"${APP_USER}\""

# Grant database-level privileges (CONNECT, CREATE, TEMP)
psql --username "postgres" -c "GRANT ALL PRIVILEGES ON DATABASE \"${APP_DB}\" TO \"${APP_USER}\""