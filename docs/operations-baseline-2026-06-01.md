# Operations Baseline - 2026-06-01

## Live Cluster

- Cluster context: `kubernetes-admin@kubernetes`
- Cluster node: `mugiwara`
- Node condition: `Ready`
- Node IP: `192.168.0.90`
- Kubernetes version: `v1.33.1`
- OS: Ubuntu 24.04.2 LTS
- Container runtime: `containerd://1.7.28`
- Non-running/non-succeeded pods: none at validation time
- Cloudflared pod: Running in namespace `networking`

## GitOps and Validation

- Flux entrypoint: root `kustomization.yaml`
- Root resource: `clusters/mugiwara`
- Apps reconciliation path: `clusters/mugiwara/apps`
- Monitoring reconciliation path: `infra/monitoring`
- Readiness command: `scripts/homelab-readiness-check.sh`
- Readiness result after the operations-doc refresh on 2026-06-01: 0 failures,
  2 expected warnings
- Expected warning: `tools.jamaguchi.xyz` has a Kubernetes Ingress but no
  Cloudflared route, so it remains internal-only by tunnel config.
- Expected warning: Longhorn uses the legacy/unsupported
  `defaultSettings.backupTarget` key until external backup storage is
  provisioned and `defaultBackupStore.backupTarget` is configured.

## Current Operational Posture

### Restores

Postgres restore smoke tests passed for:

- `keycloak`
- `ledger-dev`
- `metabase`

Evidence and the reusable restore-smoke Job template are documented in
`docs/postgres-backup-restore.md`.

### Public Exposure

Public exposure has been audited in `docs/public-ingress-exposure.md`.

- Built/live ingress hosts: 15
- Cloudflared routed hostnames: 14
- Known intentional drift: `tools.jamaguchi.xyz` is ingress-only
- Cluster-verifiable controls are separated from Cloudflare Access and
  application-auth assumptions.

### Longhorn Backups

Longhorn volume backups are not yet hardened against node loss.

- Repo values attempted same-node NFS target:
  `nfs://192.168.0.90:/srv/longhorn-backups`
- Live `BackupTarget/default` had an empty URL during the audit.
- Correct chart key for Longhorn `1.11.2` is
  `defaultBackupStore.backupTarget`.
- External backup storage was first requested through operator action
  `oa-170dcc2a-a37e-4b45-b854-c69edc4c24eb`, but that action was canceled.
- Follow-up operator action `oa-ed9b4c6c-827c-4a29-b33d-17785e2b8773` remains
  open for later completion.
- Longhorn backups remain without a hardened external target until suitable
  storage exists and the open operator action is completed.

Details are documented in `docs/longhorn-backup-target.md`.

### Secrets

Secrets are currently manual/out-of-band. Target workflow is SOPS with age and
Flux decryption. Required secret names, migration steps, and rotation procedure
are documented in `docs/secrets-workflow.md`.

## Known Follow-Ups

1. Provision an external Longhorn backup target and update
   `infra/longhorn/helmrelease.yaml` with `defaultBackupStore`.
2. Implement SOPS with age and Flux decryption for reproducible Secrets.
3. Decide whether `tools.jamaguchi.xyz` should remain internal-only or receive
   Cloudflared routing with explicit auth expectations.
4. Delete or intentionally restore stale `apps/postgres/overlays/torrus-dev`.
5. Delete or update stale unused
   `infra/networking/cloudflared/manifests/configmap.yaml`.
6. Convert deprecated Kustomize `patchesStrategicMerge` usage to `patches`.

## Relevant Docs

- `docs/operations-readiness-check.md`
- `docs/postgres-backup-restore.md`
- `docs/public-ingress-exposure.md`
- `docs/longhorn-backup-target.md`
- `docs/resilience-topology.md`
- `docs/secrets-workflow.md`
