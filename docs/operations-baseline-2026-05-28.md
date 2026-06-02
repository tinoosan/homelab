# Operations Baseline - 2026-05-28

Historical note: this baseline captures a past unhealthy state. The current
healthy baseline is `docs/operations-baseline-2026-06-01.md`.

## Live Cluster

- Cluster: `mugiwara`, single control-plane node.
- Node condition: `Ready=False`.
- Blocking reason: `container runtime is down, PLEG is not healthy`.
- Node taints: `node.kubernetes.io/not-ready:NoSchedule` and `node.kubernetes.io/not-ready:NoExecute`.
- Pod summary at audit time: 16 Running, 49 Pending, 52 Terminating.
- Non-running active pods: 49 pods with `status.phase!=Running,status.phase!=Succeeded`.
- Metrics API: unavailable; `v1beta1.metrics.k8s.io` APIService was not present before adding the GitOps manifest.

## Immediate Blockers

- Live rollout validation is blocked until kubelet/containerd health is restored.
- `kubectl top nodes` and `kubectl top pods -A` cannot pass until metrics-server is reconciled and the node is Ready.
- Restore testing should not run against production PVCs while the node is NotReady and many pods are Terminating.

## Relevant Repo Paths

- Metrics API: `infra/metrics-server/`
- Prometheus/Grafana resource guardrails: `infra/monitoring/kps-helmrelease.yaml`
- Longhorn backup policy: `infra/longhorn/helmrelease.yaml`
- Postgres backup CronJobs: `apps/postgres/overlays/{keycloak,ledger-dev,metabase}/backup-cronjob.yaml`
- Image pins and workload resources: `apps/*/base/deployment.yaml`, `apps/*/overlays/prod/patch-gluetun-sidecar.yaml`, `infra/keycloak/base/deployment.yaml`, `infra/networking/cloudflared/manifests/deployment.yaml`
- Ingress-nginx admission job pruning: `infra/ingress-nginx/delete-admission-*.yaml`
- Public exposure inventory: `docs/public-ingress-exposure.md`
- Secret workflow: `docs/secrets-workflow.md`
- Backup and restore runbook: `docs/postgres-backup-restore.md`
- Resilience topology: `docs/resilience-topology.md`
