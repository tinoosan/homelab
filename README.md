# homelab

This repo documents and version-controls my personal homelab infrastructure. It’s both a functional self-hosted environment and a portfolio project to showcase my progress with Kubernetes, GitOps, and modern DevOps practices.

## 🚀 Current Setup

- Kubernetes cluster on bare-metal Ubuntu
- FluxCD GitOps pipeline (syncs from branch `main`)
- Networking: MetalLB (L2) + ingress-nginx
  - Ingress VIP: `192.168.0.110` (LoadBalancer for `ingress-nginx-controller`)
- Storage: Longhorn
- Apps (selected)
  - Torrus (dev overlay) — Ingress `torrus.dev.jamaguchi.xyz`
  - aria2 (dev overlay)
  - it-tools (prod overlay) — Ingress `tools.jamaguchi.xyz`
  - Plex (prod overlay)
  - Keycloak (prod) — Public `keycloak.jamaguchi.xyz`, Admin `kc-admin.jamaguchi.xyz`
  - Gluetun (n8n) — Internal HTTP proxy for VPN egress
  - Postgres (torrus-dev)
  - pgAdmin (torrus-dev) — Ingress `pgadmin.dev.jamaguchi.xyz`
  - Monitoring: kube-prometheus-stack (Grafana Ingress `grafana.dev.jamaguchi.xyz`)

## 📚 Skills Demonstrated

- Kubernetes workloads, storage, and Ingress
- Identity and OIDC with Keycloak (hostname v2, split admin/public)
- VPN egress via Gluetun and per‑app proxying
- GitOps workflows with FluxCD (PRs → `main` → reconcile)
- Bare‑metal networking with MetalLB and ingress-nginx
- Observability with kube‑prometheus‑stack
- Operational runbooks for DB init, rollouts, and DNS

## 🌐 DNS & Access

- Internal DNS: use a DNS A record or `/etc/hosts` pointing desired hostnames to `192.168.0.110`.
  - Example `/etc/hosts` entries:
    - `192.168.0.110 torrus.dev.jamaguchi.xyz`
    - `192.168.0.110 pgadmin.dev.jamaguchi.xyz`
    - `192.168.0.110 grafana.dev.jamaguchi.xyz`
- Recommended: wildcard DNS `*.dev.jamaguchi.xyz → 192.168.0.110` (see issue #160)

Public access via Cloudflared
- Public hosts are proxied through Cloudflare → Cloudflared → ingress-nginx.
- Keycloak endpoints:
  - Public OIDC: `https://keycloak.jamaguchi.xyz` (issuer/realms)
  - Admin console: `https://kc-admin.jamaguchi.xyz` (protect via Cloudflare Access)
  - Implementation details: see `infra/keycloak/README.md:1`.

## 🧭 Roadmap (selected)

- TLS for Ingress hosts via cert‑manager (issue #155)
- pgAdmin persistence (PVC) (issue #154)
- Postgres backups (issue #156)
- Monitoring: Postgres exporter and dashboards (issue #157)
- Secrets rotation (issue #158)

## 🧠 Motivation

This project began with a simple goal: self-host Plex. It evolved into a structured environment where I could practice infrastructure-as-code, GitOps, and Kubernetes administration on real hardware. Everything is deployed via Flux, giving me practical experience with production-like workflows.

## 📝 License

MIT — free to reuse, but understand what you're running 🙂

---


## 🧩 Apps: Torrus

Torrus is a small web service I’m iterating on and deploying via Kustomize.

- Location: `apps/torrus`
- Base: `apps/torrus/base` (Deployment, Service, Ingress)
- Overlays:
  - Dev: `apps/torrus/overlays/dev` (namespace, config, secrets, patches)
  - Prod: `apps/torrus/overlays/prod` (namespace and prod-specific config)

Key notes
- Image: `ghcr.io/tinoosan/torrus` with environment-specific tags.
- Dev overlay adds ConfigMap/Secret and patches the Deployment/Ingress.
- Ingress hosts are environment-scoped (example: `torrus.dev...`).

### Deploying with Flux

This repo is reconciled by FluxCD from branch `main`. Workflow is PRs → `main` → Flux applies to cluster. No manual `kubectl apply` in normal operation.

### Local testing (optional)

If you want to validate manifests locally before pushing:

```
kustomize build apps/torrus/overlays/dev | kubectl apply -f -
```

Remember to create any required secrets or use the sample in `apps/torrus/overlays/dev/secret.yaml` only for non-production purposes.

### Configuration

- ConfigMap: `torrus-config` holds non-sensitive settings (e.g., client type, aria2 RPC URL, logging settings).
- Secret: `torrus-secrets` holds sensitive values (e.g., API tokens). Replace placeholder values before deploying outside of dev.

## 🔁 Workflow

Lightweight PR workflow:

1. Create a feature/fix branch from `main`.
2. Open a PR to `main`.
3. Merge the PR; Flux reconciles and applies changes to the cluster.
4. For rollouts that need a restart, bump the annotation nonce.

Rollout bump (example): update `apps/torrus/base/deployment.yaml` template annotation
- `rollout/nonce: "YYYY-MM-DDTHH:MM:SSZ"` (any change triggers a rollout)

Note: `clusters/mugiwara/ks-apps.yaml` sets `force: true` to handle immutable resource replacement when needed.

### Databases (Postgres for Torrus)

- Location: `apps/postgres` (base + `overlays/torrus-dev`)
- Init script behavior (`apps/postgres/base/init/10-create-app-user.sh`):
  - Creates/updates app user and password
  - Creates DB (outside transactions), sets DB owner
  - Grants `USAGE, CREATE` on `public` schema to the app user
- Re‑init (dev): scale StatefulSet to 0, delete PVC `data-postgres-0`, scale to 1. This reruns init.
- pgAdmin UI (torrus-dev): `pgadmin.dev.jamaguchi.xyz`
  - Default login: `torrus-dev@dev.jamaguchi.xyz` / `ChangeMePgAdmin` (change in `apps/pgadmin/overlays/torrus-dev/secret.yaml`)
  - Connect to host `postgres`, DB `torrus`, user `torrus` (password from `postgres-auth`)

Common DB operations
- Drop/recreate DB (clean slate, Postgres ≥16):
  - `DROP DATABASE "torrus" WITH (FORCE);`
  - `CREATE DATABASE "torrus" OWNER "torrus";`
- Truncate all tables in `public` (keep DB): generate TRUNCATE statements from `pg_tables`.

## 📄 Docs

- Aria2 in Kubernetes — UID/GID & Permissions Gotchas: docs/aria2-k8s-permissions.md
 - MetalLB VIP troubleshooting: docs/metallb-vip-troubleshooting.md

## 🔑 Quickstart

- DNS/hosts setup (dev): ensure hostnames resolve to the Ingress VIP `192.168.0.110`.
  - Example `/etc/hosts` entries:
    - `192.168.0.110 torrus.dev.jamaguchi.xyz`
    - `192.168.0.110 pgadmin.dev.jamaguchi.xyz`
    - `192.168.0.110 grafana.dev.jamaguchi.xyz`

- Access apps
  - Torrus: http://torrus.dev.jamaguchi.xyz
  - pgAdmin: http://pgadmin.dev.jamaguchi.xyz
    - Default login: `torrus-dev@dev.jamaguchi.xyz` / `ChangeMePgAdmin`
    - Register a server with: Host `postgres`, Port `5432`, DB `torrus`, User `torrus`, Password from Secret `postgres-auth.APP_PASSWORD`.

- Postgres maintenance (CLI)
  - Exec psql in pod: `kubectl -n torrus-dev exec -it postgres-0 -- psql -U postgres`
  - Drop/recreate DB (Postgres ≥16): `DROP DATABASE "torrus" WITH (FORCE); CREATE DATABASE "torrus" OWNER "torrus";`

## 🔄 Flux Operations

- Check reconciliation state
  - `flux get kustomizations -n flux-system`
  - `flux get sources git -n flux-system`

- Force a reconcile (useful after merging PRs)
  - Source: `flux reconcile source git flux-system -n flux-system`
  - Apps: `flux reconcile kustomization apps -n flux-system`
  - Monitoring: `flux reconcile kustomization monitoring -n flux-system`

- Tail controller logs
  - `flux logs -f -n flux-system`

- Verify rollouts
  - Torrus: `kubectl -n torrus-dev rollout status deploy/torrus`
  - Ingress NGINX LB: `kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide`
