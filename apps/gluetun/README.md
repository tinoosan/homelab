Gluetun VPN Proxy for n8n

Overview
- Runs qmcgaw/gluetun in namespace `n8n` as an internal HTTP proxy for egress through a VPN.
- n8n is configured to use the proxy via `HTTP_PROXY`/`HTTPS_PROXY` envs.
- No Ingress is exposed for Gluetun; it is cluster‑internal only.

NordVPN quickstart (OpenVPN)
1) Obtain NordVPN service credentials (not your account password):
   - https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/service-credentials/
2) Create/replace the Secret in namespace `n8n`:
   - `kubectl -n n8n delete secret vpn-secret || true`
   - `kubectl -n n8n create secret generic vpn-secret \
       --from-literal=OPENVPN_USER='your_service_username' \
       --from-literal=OPENVPN_PASSWORD='your_service_password'`
3) Deploy/roll:
   - `kubectl -n n8n rollout restart deploy/gluetun`
   - `kubectl -n n8n logs -f deploy/gluetun` (wait for connected)
4) Verify n8n egress:
   - `kubectl -n n8n exec deploy/n8n -- curl -s https://ifconfig.io`

WireGuard (alternative)
- Use `VPN_TYPE=wireguard` and provide `WIREGUARD_PRIVATE_KEY` instead of OpenVPN creds.
- Secret example:
  - `kubectl -n n8n create secret generic vpn-secret --from-literal=WIREGUARD_PRIVATE_KEY='...'`

Files
- Base Deployment/Service: `apps/gluetun/base/*`
  - Sets: `VPN_SERVICE_PROVIDER=nordvpn`, `VPN_TYPE=openvpn`, `HTTPPROXY=on` (port 8888), health checks on.
- n8n overlay uses the proxy: `apps/n8n/overlays/prod/patch-proxy.yaml`
  - `HTTP_PROXY`/`HTTPS_PROXY` → `http://gluetun.n8n.svc.cluster.local:8888`
  - `NO_PROXY` covers cluster DNS: `localhost,127.0.0.1,::1,.svc,.svc.cluster.local`
- Secret template (optional): `apps/gluetun/overlays/n8n/secret.yaml`

Optional server targeting
- Set any of the following environment variables on the Gluetun Deployment:
  - `SERVER_COUNTRIES` (e.g., `Netherlands`)
  - `SERVER_REGIONS`
  - `SERVER_CITIES`
  - `SERVER_HOSTNAMES`
  - `SERVER_CATEGORIES`

Notes
- Gluetun HTTP proxy is enabled via `HTTPPROXY=on`; no SOCKS is used.
- No Ingress is required; only n8n should reach the proxy. Consider a NetworkPolicy to restrict access to the Gluetun Service to pods with label `app=n8n`.

