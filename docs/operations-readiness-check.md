# Homelab Operations Readiness Check

This check is a read-only first pass for the Flux/Kubernetes homelab. It is
meant to catch obvious GitOps, exposure, backup, and secret-workflow gaps before
changing the live cluster.

## Run

Local repo checks:

```sh
scripts/homelab-readiness-check.sh
```

Or via the repo entrypoint:

```sh
make readiness
```

Optional live read-only checks:

```sh
scripts/homelab-readiness-check.sh --live
```

The live mode uses the current `kubectl` context and, when installed, the
`flux` CLI. It does not apply manifests or mutate cluster resources.

## Dependencies

- `kubectl` or `kustomize` for local Kustomize builds.
- `yq` for structured YAML/JSON inventory checks.
- `flux` only for optional `--live` Flux checks.

## First Iteration Scope

- Required operations docs exist:
  - `docs/operations-baseline-2026-05-28.md`
  - `docs/operations-baseline-2026-06-01.md`
  - `docs/postgres-backup-restore.md`
  - `docs/public-ingress-exposure.md`
  - `docs/longhorn-backup-target.md`
  - `docs/resilience-topology.md`
  - `docs/secrets-workflow.md`
- All discovered Kustomize roots build locally with `kustomize` or
  `kubectl kustomize`. Roots are found by walking the repo for
  `kustomization.yaml` files (excluding `.git/` and `workspace/`); a `*/base`
  directory is skipped when a sibling `*/overlays/*/kustomization.yaml` exists,
  because the overlay's build transitively exercises the base. Bases without
  any overlay are still built, so adding a new app or infra module cannot
  silently bypass the build check.
- Flux `Kustomization` resources under `clusters/mugiwara` reference existing
  repo paths that contain `kustomization.yaml`.
- Public ingress and Cloudflared exposure inventory is present.
- Built ingress hostnames are cross-referenced with Cloudflared route hostnames
  so mismatches are visible before public exposure changes.
- Built workload images are checked for explicit tags or digest pins, and
  `:latest` is treated as a failure.
- Built Deployment and StatefulSet containers without `resources.requests` are
  reported as warnings.
- Postgres backup CronJobs exist for `keycloak`, `ledger-dev`, and `metabase`
  and are included by their overlays.
- Postgres backup CronJobs include a schedule, a PVC or object-store backup
  target, and successful/failed job history limits.
- Longhorn has a backup target configured.
- Secret handling is documented, and non-example secret-like YAML files are
  flagged for manual inspection.
- YAML files are scanned for plaintext secret patterns: PEM private key blocks
  and AWS access key id patterns are FAILs in any file (including examples);
  non-example `kind: Secret` manifests committed in plaintext are FAILs.
  Example files (`*example*.yaml`) are exempt from the `kind: Secret` check.
  The scan reports file paths only — never values or matched lines.

### Plaintext secret scan: scope and limitations

- Dependencies: standard POSIX tools (`find`, `grep`). No new toolchain
  dependency beyond what the rest of the script uses.
- Scope: all `*.yaml` / `*.yml` files in the repo, excluding `.git/` and
  `workspace/`. Non-YAML files (shell, `.env`, JSON config, Dockerfiles) are
  not scanned.
- High-risk patterns flagged everywhere: `-----BEGIN [TYPE] PRIVATE KEY-----`
  PEM blocks; AWS access key id format `AKIA[0-9A-Z]{16}`.
- `kind: Secret` (non-SealedSecret) in non-example files is flagged as a
  plaintext Secret commit; SealedSecret resources are intentionally allowed.
- Not detected: kustomize `secretGenerator` literals (no `kind: Secret` line in
  the source), values stored under arbitrary application keys (e.g. plain
  `password:` fields in Helm values), tokens in shell scripts or `.env` files,
  high-entropy strings without a recognisable pattern. Use a dedicated secret
  scanner (e.g. `gitleaks`, `trufflehog`) for broader coverage.

## Operational Follow-Up

Use the existing docs for deeper checks:

- Current cluster baseline: `docs/operations-baseline-2026-06-01.md`
- Historical unhealthy baseline: `docs/operations-baseline-2026-05-28.md`
- Public routes: `docs/public-ingress-exposure.md`
- Backup and restore testing: `docs/postgres-backup-restore.md`
- Longhorn backup target: `docs/longhorn-backup-target.md`
- Secrets workflow: `docs/secrets-workflow.md`
- Multi-node resilience plan: `docs/resilience-topology.md`

## Accepted Warnings

- `tools.jamaguchi.xyz` is intentionally documented as an Ingress host without a
  Cloudflared route in `docs/public-ingress-exposure.md`.
- Longhorn currently has only the legacy/unsupported
  `defaultSettings.backupTarget` value. This remains a warning until external
  backup storage is provisioned and `defaultBackupStore.backupTarget` is used.

## Acceptance Criteria

- `scripts/homelab-readiness-check.sh` exits non-zero on missing required
  readiness artifacts.
- The default run is local and read-only.
- Live checks are opt-in via `--live`.
- The script reports actionable pass, warn, and fail lines.
- The script can be extended without adding a new toolchain dependency.
- New checks should fit the existing pattern: add one function and call it from
  `main`.
