# homelab

This repo documents and version-controls my personal homelab infrastructure. It’s both a functional self-hosted environment and a portfolio project to showcase my progress with Kubernetes, GitOps, and modern DevOps practices.

## 🚀 Current Setup

* **Kubernetes cluster** running on Ubuntu Live Server (bare metal)
* **FluxCD GitOps pipeline** to automatically apply and reconcile changes
* **Plex Media Server** deployed and exposed via NodePort
* **Declarative infrastructure** written in YAML — no `kubectl apply` needed
* **Mounted media and config volumes** for persistent Plex data

## 📚 Skills Demonstrated

* Kubernetes workload and volume configuration
* GitOps workflows with FluxCD
* Bare-metal Kubernetes service exposure (NodePort)
* Debugging YAML and Kustomize deployment issues
* Managing persistent storage in a containerized environment

## 🚫 What's Not Included

* Ingress / reverse proxy: Removed for Plex due to incompatibilities with direct stream and remote access
* Public DNS routing: Domain configuration is internal-only (via `/etc/hosts`)

## 🧭 Roadmap

* [ ] Add Prometheus and Grafana for observability
* [ ] Implement persistent storage with Longhorn or NFS
* [ ] Automate TLS certificates for future services (e.g., cert-manager)
* [ ] Deploy additional apps (Jellyfin, Nextcloud, etc.)

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

This repo is reconciled by FluxCD. Once changes are merged into `dev`, Flux applies them automatically to the dev environment. No manual `kubectl apply` is required in normal operation.

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

I use a lightweight GitFlow-style workflow:

1. Branch off `dev` for changes.
2. Commit and open a PR into `dev`.
3. Merge the PR; Flux reconciles and applies to the cluster.
4. Promote to other environments with additional PRs as needed.

