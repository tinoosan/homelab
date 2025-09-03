## MetalLB L2 VIP Not Reachable — Troubleshooting

Symptoms
- VIP doesn’t ping from LAN; ARP who-has seen, no replies.
- curl to Service NodePort works; VIP returns 404/default backend without Host header.
- Speaker logs show skipping announce or no available nodes.

Checklist
- kube-proxy strict ARP: set `ipvs.strictARP: true` in `ConfigMap/kube-proxy` and restart DaemonSet.
- L2Advertisement scope: select the right interface(s), e.g. `interfaces: [eno1]`. Avoid over-restrictive `nodeSelectors` until stable.
- Node exclusion label: remove `node.kubernetes.io/exclude-from-external-load-balancers` from nodes that should announce.
- Ingress Service policy: prefer `externalTrafficPolicy: Local` for ingress-nginx LB Services to avoid hairpin paths.
- Host header: Ingress requires the correct `Host`; without it you hit the default backend (404).

Useful commands
- Reconcile Flux: `flux reconcile kustomization flux-system -n flux-system`
- Restart daemons: `kubectl -n metallb-system rollout restart ds speaker && kubectl -n kube-system rollout restart ds kube-proxy`
- Inspect endpoints: `kubectl -n ingress-nginx get endpointslice -l kubernetes.io/service-name=ingress-nginx-controller -o wide`
- Speaker logs: `kubectl -n metallb-system logs -l app=metallb,component=speaker -c speaker --tail=200`
- ARP trace on node: `sudo tcpdump -ni eno1 arp and host <VIP>`

Expectations
- Speaker logs should include `got ARP request for service IP, sending response` on the chosen interface.
- `kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.spec.externalTrafficPolicy}\n'` prints `Local`.
- VIP ARP resolves to the node MAC; HTTP works with the correct `Host` header.

Notes
- ICMP ping is not a reliable VIP health signal with L2 LoadBalancers; prefer HTTP checks.
- Keep secrets (API tokens) in Secrets, not ConfigMaps.
