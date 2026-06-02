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

Run this only when the node is Ready and the source dump exists. The smoke
test must restore into an isolated temporary Postgres data directory and must
not run destructive commands against the live database StatefulSet.

1. Pick a non-production namespace, for example `restore-test`.
2. Copy one `.dump` file from a backup PVC to an isolated restore pod or mount a cloned PVC.
3. Start a temporary Postgres container with an empty data directory.
4. Restore with `pg_restore --clean --if-exists --no-owner --dbname "$PGDATABASE" /backups/<dump-file>`.
5. Verify with `psql` queries that expected tables exist and row counts are plausible.
6. Delete the temporary namespace and restore PVC after recording the result.

### Read-Only Backup PVC Smoke Test

This pattern mounts the namespace-local `postgres-backups` PVC read-only and
restores the newest dump into a temporary `emptyDir` Postgres instance inside a
one-shot Job. It does not connect to or mutate the live `postgres` Service or
StatefulSet.

Set `NS` and `APP_BACKUP_DIR` to one of:

| Namespace | APP_BACKUP_DIR |
| --- | --- |
| `keycloak` | `keycloak` |
| `ledger-dev` | `ledger-dev` |
| `metabase` | `metabase` |

```sh
NS=keycloak
APP_BACKUP_DIR=keycloak
JOB=postgres-restore-smoke-$(date -u +%Y%m%d)

kubectl -n "$NS" delete job "$JOB" --ignore-not-found=true
kubectl -n "$NS" apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB}
  labels:
    app.kubernetes.io/name: postgres-restore-smoke
    app.kubernetes.io/part-of: homelab-reliability
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: restore-smoke
          image: postgres:16-alpine
          imagePullPolicy: IfNotPresent
          env:
            - name: APP_BACKUP_DIR
              value: "${APP_BACKUP_DIR}"
          command:
            - /bin/sh
            - -ceu
            - |
              DUMP="\$(find "/backups/\${APP_BACKUP_DIR}" -type f -name '*.dump' | sort | tail -n 1)"
              test -n "\$DUMP"
              echo "dump=\$DUMP"
              echo "dump_bytes=\$(stat -c%s "\$DUMP")"
              echo "dump_items=\$(pg_restore -l "\$DUMP" | wc -l)"
              mkdir -p /work/pgdata /work/run
              chown -R postgres:postgres /work
              su-exec postgres initdb -D /work/pgdata >/tmp/initdb.log
              su-exec postgres pg_ctl -D /work/pgdata -o "-k /work/run -c listen_addresses=''" -w start
              su-exec postgres createdb -h /work/run restored
              su-exec postgres pg_restore -h /work/run --clean --if-exists --no-owner --no-acl --dbname restored "\$DUMP"
              su-exec postgres psql -h /work/run -d restored -Atc "select 'schemas=' || count(*) from pg_namespace where nspname not like 'pg_%' and nspname <> 'information_schema';"
              su-exec postgres psql -h /work/run -d restored -Atc "select 'user_tables=' || count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema');"
              su-exec postgres psql -h /work/run -d restored -Atc "select 'relations=' || count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname not like 'pg_%' and n.nspname <> 'information_schema';"
              su-exec postgres pg_ctl -D /work/pgdata -m fast -w stop
              echo "restore_smoke=ok"
          volumeMounts:
            - name: backups
              mountPath: /backups
              readOnly: true
            - name: work
              mountPath: /work
      volumes:
        - name: backups
          persistentVolumeClaim:
            claimName: postgres-backups
            readOnly: true
        - name: work
          emptyDir: {}
EOF

kubectl -n "$NS" wait --for=condition=complete "job/$JOB" --timeout=180s
kubectl -n "$NS" logs "job/$JOB"
kubectl -n "$NS" delete job "$JOB" --ignore-not-found=true
```

Expected successful output includes:

```text
dump=/backups/<app>/<database>-<timestamp>.dump
dump_bytes=<non-zero size>
dump_items=<non-zero count>
schemas=<count>
user_tables=<count>
relations=<count>
restore_smoke=ok
```

## Current Restore Test Status

Latest live restore smoke tests passed on 2026-06-01 with node `mugiwara`
`Ready`. The Jobs mounted only the `postgres-backups` PVCs read-only and
restored into temporary `emptyDir` Postgres instances. The temporary Jobs were
deleted after logs were captured.

| Namespace | Dump | Dump bytes | Dump items | User tables | Relations | Result |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `keycloak` | `/backups/keycloak/keycloak-20260601T022011Z.dump` | 391046 | 476 | 90 | 303 | `restore_smoke=ok` |
| `ledger-dev` | `/backups/ledger-dev/ledger-20260601T022511Z.dump` | 23491 | 44 | 5 | 14 | `restore_smoke=ok` |
| `metabase` | `/backups/metabase/metabase-20260601T023011Z.dump` | 3546347 | 1956 | 151 | 761 | `restore_smoke=ok` |

The 2026-05-28 blocker is resolved for this check: kubelet/containerd are
healthy enough for isolated restore Jobs, and no non-running pods were present
before the 2026-06-01 smoke tests.
