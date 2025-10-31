Keycloak Admin Access Strategy

This environment exposes public OIDC endpoints at `keycloak.jamaguchi.xyz` and a separate admin console at `kc-admin.jamaguchi.xyz`.

Architecture
- TLS at edge: NGINX Ingress/Cloudflared terminate TLS; pod serves HTTP on `:8080`.
- Hostname v2: full URLs in `KC_HOSTNAME` and `KC_HOSTNAME_ADMIN`.
- Proxy settings: `KC_PROXY=edge`, `KC_PROXY_HEADERS=xforwarded`, `KC_HOSTNAME_STRICT_HTTPS=true`.
- Startup: production `start --http-enabled=true` (no `--optimized` on first runs).

Implemented
- Public Ingress: `infra/keycloak/base/ingress.yaml:1` (HTTPS redirect enforced).
- Admin Ingress: `infra/keycloak/base/ingress-admin.yaml:1` with NGINX rate limiting.
- Hostnames config: `infra/keycloak/base/configmap.yaml:6`.
- Cloudflared routes: `infra/networking/cloudflared/manifests/configmap.yaml:17` (public) and `:21` (admin).

Endpoints
- Issuer: `https://keycloak.jamaguchi.xyz/realms/<realm>`
- Admin console: `https://kc-admin.jamaguchi.xyz/admin/<realm>/console/`

Rate Limiting (Admin Ingress)
- `nginx.ingress.kubernetes.io/limit-rps: "5"`
- `nginx.ingress.kubernetes.io/limit-burst-multiplier: "3"`
- `nginx.ingress.kubernetes.io/limit-connections: "20"`

Cloudflare Access (recommended)
1) Zero Trust → Access → Applications → Add application → Self‑hosted.
2) App domain: `kc-admin.jamaguchi.xyz`, Path: `/*`.
3) Policy: require SSO group or email domain; optionally device posture checks.
4) Save and test; Access should gate before the Ingress.

Cloudflared origin TLS
- Current: `noTLSVerify: true` for both hosts in `infra/networking/cloudflared/manifests/configmap.yaml:17,21`.
- Hardening (later): issue certs via cert‑manager and set `noTLSVerify: false`.

Apps Using Keycloak
- Example (ledger dev): `apps/ledger/overlays/dev/configmap.yaml:12`
  - `JWT_ISSUER` → `https://keycloak.jamaguchi.xyz/realms/internal`
  - `JWT_JWKS_URL` → internal Service URL for the same realm.

Operations
- Rollout: `kubectl -n keycloak rollout restart deploy/keycloak`
- Logs: `kubectl -n keycloak logs -f deploy/keycloak`
- OIDC metadata check: `curl -s https://keycloak.jamaguchi.xyz/realms/master/.well-known/openid-configuration | jq '.issuer'`

Admin Recovery (no data loss)
- Verify master user count:
  - `SELECT COUNT(*) FROM user_entity WHERE realm_id=(SELECT id FROM realm WHERE name='master');`
- If zero users and no admin login:
  - Create admin via CLI inside the pod, then restart:
    - `kubectl -n keycloak exec -it deploy/keycloak -- /opt/keycloak/bin/kc.sh bootstrap-admin --user admin --password 'StrongPass123!'`
    - `kubectl -n keycloak rollout restart deploy/keycloak`
- If you ever need a clean slate (will wipe realms): drop and recreate schema, then restart (not recommended unless intentional).

Notes
- Do not delete the `master` realm; it is required by Keycloak.
- Keep `KC_BOOTSTRAP_ADMIN_*` in `infra/keycloak/base/secrets.yaml:6` for first‑run initialization.
- If any app still references `http://keycloak…`, update to `https://` to match the issuer.
