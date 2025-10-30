Keycloak admin access strategy

This environment exposes public user-facing OIDC endpoints at `keycloak.jamaguchi.xyz` and a separate admin console at `kc-admin.jamaguchi.xyz`.

What’s implemented
- Separate admin Ingress: `infra/keycloak/base/ingress-admin.yaml` with HTTPS-only and NGINX rate limiting.
- Cloudflared tunnel mapping for the admin hostname in `infra/networking/cloudflared/manifests/configmap.yaml`.
- Keycloak configured with distinct hostnames via `KC_HOSTNAME` and `KC_HOSTNAME_ADMIN` in `infra/keycloak/base/configmap.yaml`.

NGINX rate limiting (admin Ingress)
- limit-rps: 5
- limit-burst-multiplier: 3
- limit-connections: 20

Gate admin via Cloudflare Access
1) In Cloudflare Zero Trust, create an "Application" → "Self-hosted" for `https://kc-admin.jamaguchi.xyz/*`.
2) Under Policies, require identity (e.g., Email domain, GitHub/GitLab SSO group) or Service Token.
3) Optionally add device posture checks (managed device, country allowlist) and short session duration for admins.
4) Save and test. Access should be enforced before requests hit your Ingress.

Notes
- Tokens and issuer remain at `https://keycloak.jamaguchi.xyz`. Admin console and admin REST use `https://kc-admin.jamaguchi.xyz`.
- If any app still references `http://keycloak.jamaguchi.xyz`, update it to `https://` to match Keycloak’s issuer/front-end URL.
- For stronger origin auth from Cloudflared → Ingress, provision a TLS certificate on Ingress and set `noTLSVerify: false`.

