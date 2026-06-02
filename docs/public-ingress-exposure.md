# Public Ingress Exposure

Date: 2026-06-01

Cloudflared publishes selected hostnames from
`infra/networking/cloudflared/config/config.yaml` to the in-cluster
`ingress-nginx-controller` Service. Ingress resources are defined by app,
infra, and Helm-rendered manifests.

This audit separates three different facts:

- **Built/live ingress**: Kubernetes will route the hostname to an in-cluster
  Service when traffic reaches ingress-nginx.
- **Cloudflared route**: the hostname is explicitly routed by the Cloudflared
  config in this repo and by the currently mounted live ConfigMap.
- **Access control**: only controls visible in Kubernetes manifests are
  cluster-verifiable here. Cloudflare Access policies and application auth must
  be verified outside this repo unless they are represented in manifests.

## Inventory

Built manifests and live cluster both expose these Ingress hosts. Cloudflared
routes were checked against both `infra/networking/cloudflared/config/config.yaml`
and the live generated ConfigMap `networking/cloudflared-config-b5g28m2gdm`
at audit time.

| Hostname | Namespace / Ingress | Cloudflared route | Sensitivity | Cluster-verifiable controls | External/app controls to verify | Action |
| --- | --- | --- | --- | --- | --- | --- |
| `keycloak.jamaguchi.xyz` | `keycloak/keycloak` | Yes, HTTPS origin with `noTLSVerify` | Public identity endpoint | NGINX `ssl-redirect` and `force-ssl-redirect` | Keycloak realm/client config; Cloudflare DNS/tunnel route | Keep public if issuer URL requires it; replace `noTLSVerify` with trusted origin TLS when cert-management is ready. |
| `kc-admin.jamaguchi.xyz` | `keycloak/keycloak-admin` | Yes, HTTPS origin with `noTLSVerify` | Admin-critical | NGINX `ssl-redirect`, `force-ssl-redirect`, `limit-rps=5`, `limit-burst-multiplier=3`, `limit-connections=20` | Cloudflare Access; Keycloak admin auth; MFA | Treat Cloudflare Access as required; verify policy in Cloudflare dashboard. |
| `grafana.jamaguchi.xyz` | `monitoring/kube-prom-stack-grafana` | Yes | Admin-sensitive | No auth policy visible in Ingress; Helm ownership annotations only | Grafana login; Cloudflare Access; admin user/secret rotation | Require Cloudflare Access or equivalent; monitoring can expose infrastructure details. |
| `pgadmin.jamaguchi.xyz` | `tools/pgadmin` | Yes | Admin-critical | No auth policy visible in Ingress | PgAdmin login; Cloudflare Access | Require Cloudflare Access; database admin surface should not be anonymously reachable. |
| `n8n.jamaguchi.xyz` | `n8n/n8n` | Yes | Admin-sensitive | No auth policy visible in Ingress | n8n auth; Cloudflare Access | Verify app auth is enabled and prefer Cloudflare Access. |
| `ledger.dev.jamaguchi.xyz` | `ledger-dev/ledger` | Yes | Dev app/API | No auth policy visible in Ingress | App auth if any; Cloudflare Access for dev-only exposure | Restrict unless intentionally public; document intended audience. |
| `metabase.jamaguchi.xyz` | `metabase/metabase` | Yes | Data-sensitive | No auth policy visible in Ingress | Metabase login; Cloudflare Access for admin/data access | Require strong app auth; prefer Cloudflare Access for non-public analytics. |
| `homarr.jamaguchi.xyz` | `homarr/homarr` | Yes | Internal dashboard | No auth policy visible in Ingress | Homarr auth if enabled; Cloudflare Access | Protect with Access if dashboard links reveal internal services. |
| `qbittorrent.jamaguchi.xyz` | `qbittorrent/qbittorrent` | Yes | Admin-sensitive download client | No auth policy visible in Ingress | qBittorrent auth; Cloudflare Access | Require Cloudflare Access and app auth. |
| `transmission.jamaguchi.xyz` | `transmission/transmission` | Yes | Admin-sensitive download client | No auth policy visible in Ingress | Transmission auth; Cloudflare Access | Require Cloudflare Access and app auth. |
| `sonarr.jamaguchi.xyz` | `sonarr/sonarr` | Yes | Admin-sensitive media automation | No auth policy visible in Ingress | App auth/API key controls; Cloudflare Access | Require Cloudflare Access. |
| `radarr.jamaguchi.xyz` | `radarr/radarr` | Yes | Admin-sensitive media automation | No auth policy visible in Ingress | App auth/API key controls; Cloudflare Access | Require Cloudflare Access. |
| `prowlarr.jamaguchi.xyz` | `prowlarr/prowlarr` | Yes | Admin-sensitive indexer | No auth policy visible in Ingress | App auth/API key controls; Cloudflare Access | Require Cloudflare Access. |
| `excalidraw.jamaguchi.xyz` | `tools/excalidraw` | Yes | Low/medium, depends on use | No auth policy visible in Ingress | App-level storage/auth expectations; Cloudflare Access if private | Public may be acceptable only if no private collaboration data is expected. |
| `tools.jamaguchi.xyz` | `tools/it-tools` | No | Low/medium utility app | No auth policy visible in Ingress | Internal DNS/VIP access only unless Cloudflared route is added | Current state is internal-only by tunnel config. Add route only with explicit exposure intent. |

## Cross-Check Summary

- Built ingress host count: 15.
- Live ingress host count: 15.
- Cloudflared routed hostname count: 14.
- Drift: `tools.jamaguchi.xyz` has a Kubernetes Ingress but no Cloudflared
  route. This is acceptable only if it remains intentionally internal-only.
- Cloudflared default route is `http_status:404`.
- The live `cloudflared` pod is running and mounts generated ConfigMap
  `cloudflared-config-b5g28m2gdm`.

## Cluster-Verifiable Controls

The cluster manifests prove:

- `keycloak.jamaguchi.xyz` and `kc-admin.jamaguchi.xyz` use NGINX HTTPS redirect
  annotations.
- `kc-admin.jamaguchi.xyz` has NGINX rate limiting annotations.
- Cloudflared routes 14 explicit hostnames to ingress-nginx and has a default
  404 catch-all.
- `tools.jamaguchi.xyz` is not routed by Cloudflared.

The cluster manifests do not prove:

- Cloudflare Access policies are present or correct.
- Cloudflare DNS public hostname entries exactly match this repo.
- Application-level authentication is enabled or strong.
- End-to-end origin TLS is trusted for Keycloak routes, because Cloudflared
  currently uses `noTLSVerify: true` for the two Keycloak origins.

## Exposure Drift Notes

1. `tools.jamaguchi.xyz` is an Ingress-only host. Keep it internal-only or add
   Cloudflared routing with a documented auth expectation.
2. `infra/networking/cloudflared/manifests/configmap.yaml` is a stale static
   manifest and is not referenced by `infra/networking/cloudflared/kustomization.yaml`.
   The active source of truth is `config/config.yaml` through
   `configMapGenerator`. Delete or update the stale static manifest to avoid
   future audit confusion.
3. Most public routes rely on app auth and/or Cloudflare Access, but those
   controls are not expressed in Kubernetes manifests. Verify them in
   Cloudflare and the applications before treating the surfaces as protected.

## Validation Commands

```sh
kubectl kustomize clusters/mugiwara/apps >/tmp/homelab-apps-built.yaml
kubectl kustomize infra >/tmp/homelab-infra-built.yaml

yq -r 'select(.kind == "Ingress") | [.metadata.namespace, .metadata.name, (.spec.rules[].host // "")] | @tsv' /tmp/homelab-apps-built.yaml
yq -r 'select(.kind == "Ingress") | [.metadata.namespace, .metadata.name, (.spec.rules[].host // "")] | @tsv' /tmp/homelab-infra-built.yaml

kubectl get ingress -A -o json |
  jq -r '.items[] | [.metadata.namespace, .metadata.name, (.spec.rules[]?.host // "")] | @tsv'

yq -r '.ingress[] | select(has("hostname")) | [.hostname, .service] | @tsv' \
  infra/networking/cloudflared/config/config.yaml

kubectl -n networking get deploy cloudflared \
  -o jsonpath='{range .spec.template.spec.volumes[*]}{.name}{"\t"}{.configMap.name}{"\n"}{end}'

CM=$(kubectl -n networking get deploy cloudflared \
  -o jsonpath='{.spec.template.spec.volumes[?(@.name=="cfg")].configMap.name}')

kubectl -n networking get cm "$CM" -o jsonpath='{.data.config\.yaml}' |
  yq -r '.ingress[] | select(has("hostname")) | [.hostname, .service] | @tsv'
```
