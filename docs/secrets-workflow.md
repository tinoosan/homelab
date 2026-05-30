# Secret Workflow

The repo currently keeps only example Secret manifests in Git and expects live values to be created out-of-band. Keep that policy until SOPS or External Secrets is introduced; do not commit raw secret values.

## Current Standard

1. Commit `*.example.yaml` files with placeholder values only.
2. Create live Secrets with `kubectl create secret generic ...` or a one-time sealed/encrypted workflow outside Git.
3. Reference Secrets from manifests by stable names such as `pg-secret`, `vpn-secret`, `cloudflared-secret`, `grafana-admin`, and app-specific secret names.
4. Document required keys next to the consuming app.

## Required Secret Names

| Secret | Namespace | Required keys | Consumers |
| --- | --- | --- | --- |
| `pg-secret` | `keycloak` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Keycloak Postgres and backup CronJob |
| `pg-secret` | `ledger-dev` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Ledger Postgres and backup CronJob |
| `pg-secret` | `metabase` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Metabase Postgres and backup CronJob |
| `cloudflared-secret` | `networking` | `TUNNEL_TOKEN` | Cloudflared tunnel |
| `vpn-secret` | app namespaces using Gluetun | Provider-specific Gluetun keys | Gluetun sidecars |
| `grafana-admin` | `monitoring` | `admin-user`, `admin-password` | Grafana |
| `aria2-secrets` | `aria2` | `ARIA2_SECRET` | Aria2 RPC |

## Recommended Next Step

Adopt SOPS with age for GitOps-managed Secrets:

- Add `.sops.yaml` with an age recipient for the cluster.
- Store encrypted `Secret` manifests as `*.sops.yaml`.
- Configure Flux SOPS decryption on the cluster `Kustomization`.
- Keep `*.example.yaml` files as human-readable templates.

Until that is implemented, backup and restore manifests are reproducible but depend on the live Secrets above being created manually.
