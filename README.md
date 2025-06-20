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


