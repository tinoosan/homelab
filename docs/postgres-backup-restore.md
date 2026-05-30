# Postgres Backup and Restore

## Backup Coverage

The repo defines daily `postgres-backup` CronJobs for:

- `keycloak/postgres`, writing to `keycloak/postgres-backups`
- `ledger-dev/postgres`, writing to `ledger-dev/postgres-backups`
- `metabase/postgres`, writing to `metabase/postgres-backups`

Each job uses `postgres:16-alpine`, reads `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` from `pg-secret`, runs `pg_dump -Fc`, and removes dumps older than 14 days from the namespace-local backup PVC.

## Verify Backups

```sh
kubectl -n keycloak get cronjob postgres-backup
kubectl -n ledger-dev get cronjob postgres-backup
kubectl -n metabase get cronjob postgres-backup
kubectl -n keycloak create job --from=cronjob/postgres-backup postgres-backup-manual
kubectl -n keycloak logs job/postgres-backup-manual
```

## Restore Test Procedure

Run this only when the node is Ready and the source dump exists.

1. Pick a non-production namespace, for example `restore-test`.
2. Copy one `.dump` file from a backup PVC to an isolated restore pod or mount a cloned PVC.
3. Start a temporary Postgres container with an empty data directory.
4. Restore with `pg_restore --clean --if-exists --no-owner --dbname "$PGDATABASE" /backups/<dump-file>`.
5. Verify with `psql` queries that expected tables exist and row counts are plausible.
6. Delete the temporary namespace and restore PVC after recording the result.

## Current Restore Test Status

Live restore execution is blocked on 2026-05-28 because node `mugiwara` is `Ready=False` due to container runtime and PLEG health. Do not run production-adjacent restore tests until kubelet/containerd health is restored.
