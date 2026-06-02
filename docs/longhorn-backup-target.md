# Longhorn Backup Target Assessment

Date: 2026-06-01

## Summary

Longhorn volume backups are not currently hardened against node loss.

The GitOps values in `infra/longhorn/helmrelease.yaml` attempt to set a backup
target at `nfs://192.168.0.90:/srv/longhorn-backups`, but that endpoint is in
the same failure domain as the only Kubernetes node, `mugiwara`
(`192.168.0.90`). Losing the node would likely lose the Longhorn data path and
the configured NFS backup path together.

There is also an implementation drift issue: Longhorn chart `1.11.2` uses
`defaultBackupStore.backupTarget`, not `defaultSettings.backupTarget`. The live
`BackupTarget/default` currently has an empty URL and is unavailable, so
Longhorn volume backup jobs are not actually configured with a usable target.

## Evidence

Repo configuration:

```yaml
spec:
  values:
    defaultSettings:
      backupTarget: nfs://192.168.0.90:/srv/longhorn-backups
      backupstorePollInterval: 300
```

Live node identity:

```text
NAME       STATUS   ROLES           INTERNAL-IP
mugiwara   Ready    control-plane   192.168.0.90
```

Live Longhorn backup target:

```text
BackupTarget/default:
  spec.backupTargetURL: ""
  status.available: false
  condition: backup target URL is empty
```

Live Longhorn recurring jobs:

```text
No recurringjobs.longhorn.io resources found in longhorn-system.
```

Local host check:

```text
hostname: mugiwara
eno1: 192.168.0.90/24
/srv exists, but /srv/longhorn-backups was not present
nfs-server: inactive
nfs-kernel-server: inactive
```

## Target State

Use a backup target outside the Kubernetes node and outside the Longhorn data
path. Suitable options:

1. NFS export on a different always-on host or NAS.
2. S3-compatible object storage, preferably outside the physical node.
3. Cloud object storage if cost and credentials management are acceptable.

For this homelab, a separate NAS or small storage host is the simplest next
step. The minimum target should survive complete loss or reinstall of
`mugiwara`.

## Required GitOps Shape

After external storage exists, configure Longhorn with the chart-supported
`defaultBackupStore` key:

```yaml
spec:
  values:
    defaultBackupStore:
      backupTarget: nfs://<external-host>:/<export-path>
      pollInterval: 300
```

If credentials are required, add a Kubernetes Secret outside plaintext Git and
reference it with:

```yaml
spec:
  values:
    defaultBackupStore:
      backupTarget: s3://<bucket>@<region>/
      backupTargetCredentialSecret: <secret-name>
      pollInterval: 300
```

Do not set `defaultBackupStore.backupTarget` to
`nfs://192.168.0.90:/srv/longhorn-backups` except as an explicitly accepted
same-node risk. It would improve Longhorn configuration correctness but would
not improve disaster recovery from node loss.

## Recommendation

Do not activate the current same-node NFS target. Instead:

1. Provision an external backup destination.
2. Confirm the Kubernetes node can reach and mount or authenticate to it.
3. Update `infra/longhorn/helmrelease.yaml` to use `defaultBackupStore`.
4. Reconcile Flux and verify `BackupTarget/default` is available.
5. Trigger one on-demand Longhorn backup for a low-risk PVC and confirm a
   `backups.longhorn.io` record appears.
6. Document the restore path from the external backup target.

## Temporary Open Risk

Status: open as of 2026-06-01.

External backup storage remains the target state, but the operator action to
provision it, `oa-170dcc2a-a37e-4b45-b854-c69edc4c24eb`, was canceled. A new
operator action, `oa-ed9b4c6c-827c-4a29-b33d-17785e2b8773`, is open for later
completion.

Until that is complete:

- Leave Longhorn volume backups without a hardened external target.
- Do not activate the same-node NFS target at
  `nfs://192.168.0.90:/srv/longhorn-backups`.
- Keep relying temporarily on application-level backups, especially the
  validated Postgres logical backups in `docs/postgres-backup-restore.md`.
- Keep `scripts/homelab-readiness-check.sh` warning on the legacy Longhorn
  backup key so the risk remains visible.

This is not a completed hardening item. It does not protect media/app PVCs or
Longhorn-managed non-Postgres state from node loss. Complete the open operator
action when a NAS, separate storage host, or S3-compatible target is available.
