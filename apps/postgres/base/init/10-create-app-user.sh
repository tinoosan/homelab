#!/bin/sh
set -e

# These are expected to be provided by the overlay Secret via the Pod env.
: "${APP_DB:?APP_DB not set}"
: "${APP_USER:?APP_USER not set}"
: "${APP_PASSWORD:?APP_PASSWORD not set}"

echo "Ensuring app role and database exist: $APP_DB / $APP_USER"

# Ensure role exists and set password.
# Use psql variables to safely inject env values while keeping DO $$ intact.
psql -v ON_ERROR_STOP=1 \
     -v APP_USER="${APP_USER}" \
     -v APP_PASSWORD="${APP_PASSWORD}" \
     --username "postgres" <<-'SQL'
  DO $$
  DECLARE
    v_user text := :'APP_USER';
    v_pass text := :'APP_PASSWORD';
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = v_user) THEN
      EXECUTE format('CREATE USER %I WITH PASSWORD %L', v_user, v_pass);
    ELSE
      EXECUTE format('ALTER USER %I WITH PASSWORD %L', v_user, v_pass);
    END IF;
  END
  $$;
SQL

# CREATE DATABASE cannot run inside a transaction/DO block. Check-and-create in separate commands.
if ! psql -tA --username "postgres" -c "SELECT 1 FROM pg_database WHERE datname = '${APP_DB}'" | grep -q '^1$'; then
  psql --username "postgres" -c "CREATE DATABASE \"${APP_DB}\""
fi

# Grant privileges
psql --username "postgres" -c "GRANT ALL PRIVILEGES ON DATABASE \"${APP_DB}\" TO \"${APP_USER}\""
