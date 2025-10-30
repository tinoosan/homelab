# Cloudflare Tunnel for Cluster Ingress

Publish existing Kubernetes ingress (nginx) to the public internet via Cloudflare Tunnel without opening router ports.

## What this includes
- Namespace `networking`
- ConfigMap `cloudflared-config` with ingress hostname routing to the in-cluster nginx controller
- Deployment `cloudflared` running in token mode and reading config from the ConfigMap
- Root infra kustomization reference (see below)

## Operator steps (one-time, outside Git)
1. In Cloudflare Dashboard, add your domain if not already.
2. Create a new Tunnel (Zero Trust → Access → Tunnels). Copy the Tunnel Token.
3. In the Tunnel “Public Hostnames” section, add entries for each hostname (e.g., `n8n.jamaguchi.xyz`, `aria2.jamaguchi.xyz`). Target should be HTTP with URL pointing to your in-cluster nginx controller service (no TLS needed inside cluster). Cloudflare will create DNS records.
4. Create the Kubernetes Secret in the cluster (or manage via SOPS/Flux):
   ```bash
   kubectl -n networking create secret generic cloudflared-secret \
     --from-literal=TUNNEL_TOKEN='<paste-token-here>'
   ```
5. Apply/reconcile the manifests (e.g., via Flux). Verify the `cloudflared` Pod is Running.
6. Test external access, e.g., `curl -I https://n8n.jamaguchi.xyz`.

## Notes
- Keep authentication/authorization at the application layer as appropriate.
- For strict end-to-end TLS later, use Cloudflare Origin Certificates and change the `service:` URL(s) to `https://` with valid origin certs.
- Contact: you@example.com

## Files
- `manifests/namespace.yaml`: creates `networking` namespace.
- `manifests/configmap.yaml`: cloudflared config with public hostnames routing to nginx controller.
- `manifests/deployment.yaml`: cloudflared token-run deployment.

## Secret (not in Git)
If you want a template example (not applied by GitOps), see `manifests/secret.example.yaml`.
