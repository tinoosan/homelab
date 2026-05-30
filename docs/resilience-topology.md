# Resilience Topology

## Current State

The cluster is a single-node Kubernetes homelab. It is convenient and simple, but the node is a single point of failure for scheduling, control plane, storage attachment, and local services.

## Target Option

Move to a three-node topology when hardware is available:

- Three Kubernetes nodes, all schedulable.
- Longhorn replica count of 2 for small clusters; increase selected critical volumes to 3 once capacity is available.
- Keep one control-plane node acceptable for homelab simplicity, or run stacked etcd on three nodes if control-plane uptime becomes a priority.
- Spread high-impact workloads with pod anti-affinity where practical.
- Keep hostPath-dependent media workloads intentionally tied to nodes with the required mounts unless shared storage replaces those paths.

## Storage Implications

- Longhorn needs enough disk on at least two nodes for replica count 2.
- Backup target must be outside the Longhorn data path. Current GitOps config points Longhorn backups at `nfs://192.168.0.90:/srv/longhorn-backups`; production use should move this to separate storage or another host.
- Postgres logical backups are still required because volume snapshots alone do not prove application-level restoreability.

## Preferred Next Step

Stabilize the current single node first: restore kubelet/containerd health, Metrics API, and workload resource limits. Then add a second worker with Longhorn storage and migrate non-hostPath stateful workloads to two replicas where supported.
