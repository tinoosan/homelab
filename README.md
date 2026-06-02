# homelab

This repo version-controls a personal bare-metal Kubernetes homelab. It is a
working self-hosted environment and a portfolio project for Kubernetes, Flux
GitOps, storage, ingress, observability, and operational runbooks.

## Current Setup

- Cluster: single-node Kubernetes on bare-metal Ubuntu, node `mugiwara`
- GitOps: Flux syncs this repository from branch `main`
- Entrypoint: root `kustomization.yaml` points to `clusters/mugiwara`
- Networking: MetalLB L2 plus ingress-nginx
  - Ingress VIP: `192.168.0.110`
- Storage: Longhorn
- Public tunnel: Cloudflared routes selected public hostnames to ingress-nginx
- Observability: kube-prometheus-stack and metrics-server
- Identity: Keycloak with split public and admin hostnames

## Inventory

Core infrastructure:

| Area | Path |
| --- | --- |
| Cluster wiring | `clusters/mugiwara/` |
| Flux system | `flux-system/` |
| Ingress / MetalLB / storage / monitoring | `infra/` |
| Cloudflared public routing | `infra/networking/cloudflared/` |
| Keycloak identity | `infra/keycloak/` |

Applications:

| App | Namespace | Public/Internal host notes |
| --- | --- | --- |
| aria2 | `aria2` | No ingress; Gluetun sidecar |
| Excalidraw | `tools` | `excalidraw.jamaguchi.xyz` |
| Homarr | `homarr` | `homarr.jamaguchi.xyz` |
| IT Tools | `tools` | `tools.jamaguchi.xyz`; ingress-only, not routed by Cloudflared |
| Ledger | `ledger-dev` | `ledger.dev.jamaguchi.xyz` |
| Metabase | `metabase` | `metabase.jamaguchi.xyz` |
| n8n | `n8n` | `n8n.jamaguchi.xyz`; Gluetun sidecar |
| pgAdmin | `tools` | `pgadmin.jamaguchi.xyz` |
| Plex | `default` | Host/device dependent; no ingress |
| Prowlarr | `prowlarr` | `prowlarr.jamaguchi.xyz`; Gluetun sidecar |
| qBittorrent | `qbittorrent` | `qbittorrent.jamaguchi.xyz`; Gluetun sidecar |
| Radarr | `radarr` | `radarr.jamaguchi.xyz`; Gluetun sidecar |
| Sonarr | `sonarr` | `sonarr.jamaguchi.xyz` |
| Transmission | `transmission` | `transmission.jamaguchi.xyz`; Gluetun sidecar |

Postgres overlays are wired for:

- `keycloak`
- `ledger-dev`
- `metabase`

Each has a namespace-local backup CronJob and restore smoke-test coverage in
`docs/postgres-backup-restore.md`.

## DNS and Access

Internal access to ingress hosts resolves to the MetalLB ingress VIP:

```text
192.168.0.110
```

Useful internal DNS examples:

```text
192.168.0.110 keycloak.jamaguchi.xyz
192.168.0.110 kc-admin.jamaguchi.xyz
192.168.0.110 grafana.jamaguchi.xyz
192.168.0.110 pgadmin.jamaguchi.xyz
```

Public access is routed through Cloudflare Tunnel:

```text
Cloudflare -> cloudflared -> ingress-nginx -> Kubernetes Service
```

Public exposure details and required auth assumptions are tracked in
`docs/public-ingress-exposure.md`.

## GitOps Workflow

Normal workflow:

1. Create a branch from `main`.
2. Make repo changes.
3. Validate locally.
4. Merge to `main`.
5. Flux reconciles the cluster from Git.

Useful checks:

```sh
scripts/homelab-readiness-check.sh
kubectl kustomize clusters/mugiwara/apps >/tmp/homelab-apps.yaml
kubectl kustomize infra >/tmp/homelab-infra.yaml
flux get kustomizations -n flux-system
flux get sources git -n flux-system
```

Force reconcile when needed:

```sh
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization apps -n flux-system
flux reconcile kustomization monitoring -n flux-system
```

## Operations Docs

| Topic | Doc |
| --- | --- |
| Current operations baseline | `docs/operations-baseline-2026-06-01.md` |
| Readiness check design | `docs/operations-readiness-check.md` |
| Backup and restore | `docs/postgres-backup-restore.md` |
| Longhorn backup target | `docs/longhorn-backup-target.md` |
| Public ingress exposure | `docs/public-ingress-exposure.md` |
| Resilience topology | `docs/resilience-topology.md` |
| Secrets workflow | `docs/secrets-workflow.md` |
| MetalLB troubleshooting | `docs/metallb-vip-troubleshooting.md` |
| Aria2 permissions | `docs/aria2-k8s-permissions.md` |

## Known Risks

- Single-node Kubernetes remains the dominant availability risk.
- Longhorn volume backups need an external target outside `mugiwara`; see
  `docs/longhorn-backup-target.md`.
- Cloudflare Access and app-level auth policies are not fully provable from
  Kubernetes manifests; see `docs/public-ingress-exposure.md`.
- Secrets are currently manual/out-of-band. The target workflow is SOPS with
  age and Flux decryption; see `docs/secrets-workflow.md`.
- `apps/postgres/overlays/torrus-dev` remains a stale orphaned overlay and
  should be deleted or intentionally restored.

## License

MIT
