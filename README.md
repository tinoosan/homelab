# homelab

This repo is a personal project designed to document and version-control the infrastructure I’m building for my homelab. It serves both as a functional self-hosted stack and a portfolio piece demonstrating my growing knowledge of Kubernetes, GitOps, and modern DevOps practices.

## 🚀 Current Setup

- **Kubernetes cluster** on [Ubuntu server]
- **FluxCD GitOps** pipeline to automatically apply config changes
- **Plex Media Server** deployed via Kubernetes
- Configuration structured as declarative YAML (no `kubectl apply` needed)

## 📚 Skills Demonstrated

- Kubernetes manifest authoring
- GitOps with FluxCD
- Deployment strategies
- Managing media storage in containers
- Debugging YAML + Kustomize issues

## 🧭 Roadmap

- [ ] Add Prometheus/Grafana for metrics
- [ ] Include persistent storage (e.g., Longhorn or NFS)
- [ ] Automate HTTPS with Ingress + cert-manager
- [ ] Host additional services (e.g., Jellyfin, Nextcloud)

## 🧠 Motivation

This project started as a way to self-host Plex, but grew into a structured environment where I could practice and demonstrate practical DevOps skills. Everything is managed declaratively and pushed via Git to match real-world operational practices.

## 📝 License

MIT — free to reuse, but do your own homework 🙂

