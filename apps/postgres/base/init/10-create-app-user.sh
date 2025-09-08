#!/bin/sh
set -e

# These are expected to be provided by the overlay Secret via the Pod env.
: "${APP_DB:?APP_DB not set}"
: "${APP_USER:?APP_USER not set}"
: "${APP_PASSWORD:?APP_PASSWORD not set}"

echo "Creating app database and user: $APP_DB / $APP_USER"
psql -v ON_ERROR_STOP=1 --username "postgres" <<-SQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_DB}') THEN
      CREATE DATABASE "${APP_DB}";
    END IF;
  END
  \$\$;

  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${APP_USER}') THEN
      CREATE USER "${APP_USER}" WITH PASSWORD '${APP_PASSWORD}';
    ELSE
      ALTER USER "${APP_USER}" WITH PASSWORD '${APP_PASSWORD}';
    END IF;
  END
  \$\$;

  GRANT ALL PRIVILEGES ON DATABASE "${APP_DB}" TO "${APP_USER}";
SQL
