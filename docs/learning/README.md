# Homelab Handbook

Understand how the homelab works, why it is configured that way, and how to operate it without relying on someone else to remember the details.

This is a reference handbook, not an activity log. Chapters explain concepts through real configuration, then show how to inspect, maintain and troubleshoot the system. The private website renders these Markdown chapters. Edit the chapters, then rebuild the site; do not maintain a separate HTML copy.

## Read the Homelab Handbook

- [Docker, Compose and n8n](docker-and-n8n.md): understand an application deployment from its configuration, including image versions, networking and persistent storage.
- [How the private media stack works](media-stack.md): follow a request through Tailscale, Gluetun, the Arr applications and Transmission, then learn how storage and the VPN kill switch fit together.
- [Excalidraw and draw.io](drawing-apps.md): choose an editor, understand where drawings live, and save recoverable files.
- [How private PDF processing works](stirling-pdf.md): follow a document through Tailscale and Docker, then learn which data persists and how to diagnose failures.
- [How monitoring works](monitoring.md): learn how exporters, Prometheus and Grafana turn host and container measurements into useful history.
- [Homelab overview](../../README.md): the existing repository structure and Kubernetes architecture.

## Chapter structure

Each service chapter should answer:

1. **What is running?** Components, responsibilities and connections.
2. **How is it configured?** Complete examples with explanations of meaningful settings.
3. **Why this configuration?** Tradeoffs and when another choice is appropriate.
4. **Where does its data live?** Storage ownership, permissions and backup requirements.
5. **How do I operate it?** Start, stop, inspect, update and recover.
6. **How do I diagnose a failure?** Symptoms, checks and what the results mean.

Explain a concept before asking the reader to use it. Label example configurations as examples rather than implying they are deployed. Where configuration is maintained elsewhere in the repository, link to that owner and avoid a second copy that can drift.

## How to read a chapter

Start with the mental model and diagram. Then read the live configuration one
piece at a time. Commands appear only after the chapter explains what they can
change. Each chapter ends with failure symptoms and checks that narrow the
problem instead of offering a pile of commands to try.

The source files and running system remain authoritative. A chapter teaches
you how to reason about them. If a chapter disagrees with the configuration,
inspect the running system, fix the stale chapter and record why it changed.

## Topics to develop

### Containers and applications

Images versus containers; Compose projects; image tags and digests; startup and health checks; resource limits; logs; upgrades and rollback.

### Storage and recovery

Named volumes versus bind mounts; ownership and permissions; consistent backups; encryption-key recovery; restore testing; separating media from application state.

### Networking and access

Loopback, LAN and container networking; DNS; reverse proxies; TLS; Tailscale; Cloudflare Tunnel; keeping an editor private while accepting authenticated public webhooks.

### Hosts and orchestration

Linux service management; Docker permissions; Kubernetes credentials and RBAC; GitOps reconciliation; deciding when Kubernetes is useful; separating a media server from other workloads.

### Safe administration

Scope a change, inspect dependencies, preserve data, verify the result and prepare a rollback. These principles apply whether a person or an assistant executes the commands.

## Documentation boundaries

Never include passwords, tokens, encryption keys, kubeconfig contents, recovery codes or private keys. Show secret references and explain how to manage them instead.

Keep infrastructure documentation private by default. A public website needs a separate review for internal hostnames, addresses and other sensitive details. The website should render this handbook rather than become a separately maintained source.
