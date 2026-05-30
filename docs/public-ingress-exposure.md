# Public Ingress Exposure

Cloudflared publishes the hostnames in `infra/networking/cloudflared/config/config.yaml` to the in-cluster ingress-nginx controller. Ingress resources are defined in each app's `base/ingress.yaml` or overlay patch.

| Hostname | Namespace | Backend service | Auth expectation | Risk note |
| --- | --- | --- | --- | --- |
| `n8n.jamaguchi.xyz` | `n8n` | `n8n` | App auth; prefer Cloudflare Access for admin UI. | Automation UI should not be anonymously reachable. |
| `ledger.dev.jamaguchi.xyz` | `ledger-dev` | `ledger` | App auth or dev-only Cloudflare Access. | Dev API hostname; restrict unless intentionally public. |
| `pgadmin.jamaguchi.xyz` | `tools` | `pgadmin` | PgAdmin login plus Cloudflare Access. | Database admin surface; treat Access as required. |
| `keycloak.jamaguchi.xyz` | `keycloak` | `keycloak` | Keycloak public auth endpoints. | Public identity endpoint is intentional. |
| `kc-admin.jamaguchi.xyz` | `keycloak` | `keycloak` | Cloudflare Access plus Keycloak admin auth. | Admin endpoint should be explicitly protected. |
| `grafana.jamaguchi.xyz` | `monitoring` | `kube-prom-stack-grafana` | Grafana login plus Cloudflare Access. | Monitoring data can expose infrastructure details. |
| `homarr.jamaguchi.xyz` | `homarr` | `homarr` | App auth or Cloudflare Access. | Dashboard may expose internal service links. |
| `metabase.jamaguchi.xyz` | `metabase` | `metabase` | Metabase login plus Cloudflare Access for admin roles. | Analytics can expose application data. |
| `excalidraw.jamaguchi.xyz` | `tools` | `excalidraw` | Public or Access depending on intended collaboration. | Low sensitivity if no private storage is attached. |
| `sonarr.jamaguchi.xyz` | `sonarr` | `sonarr` | Cloudflare Access required. | Media automation admin UI. |
| `prowlarr.jamaguchi.xyz` | `prowlarr` | `prowlarr` | Cloudflare Access required. | Indexer/admin UI. |
| `radarr.jamaguchi.xyz` | `radarr` | `radarr` | Cloudflare Access required. | Media automation admin UI. |
| `qbittorrent.jamaguchi.xyz` | `qbittorrent` | `qbittorrent` | App auth plus Cloudflare Access. | Download client UI; protect strongly. |
| `transmission.jamaguchi.xyz` | `transmission` | `transmission` | App auth plus Cloudflare Access. | Download client UI; protect strongly. |

Default route is `http_status:404`; new public hostnames should be added here with an explicit auth expectation before deployment.

## Exposure Drift Notes

- `tools.jamaguchi.xyz` is defined by `apps/it-tools/base/ingress.yaml`, but
  it is not currently published by `infra/networking/cloudflared/config/config.yaml`.
  Treat this as internal-only until a Cloudflared route and explicit auth
  expectation are added to this inventory.
