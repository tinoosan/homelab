# Secret Workflow

## Current Policy

Do not commit raw Kubernetes `Secret` manifests or secret values.

The repo currently keeps only example manifests in Git and expects live values
to be created out-of-band. This is acceptable for short-term homelab operation,
but it is not fully reproducible. The target workflow is **SOPS with age,
decrypted by Flux**.

## Current Standard

1. Commit `*.example.yaml` files with placeholder values only.
2. Create live Secrets manually with `kubectl create secret generic ...` until
   SOPS is implemented.
3. Reference Secrets from workloads by stable names.
4. Document required keys next to the consuming app or in this file.
5. Never put real tokens, passwords, private keys, API keys, or tunnel tokens in
   plaintext YAML.

## Required Secret Names

| Secret | Namespace | Required keys | Consumers |
| --- | --- | --- | --- |
| `pg-secret` | `keycloak` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Keycloak Postgres and backup CronJob |
| `pg-secret` | `ledger-dev` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Ledger Postgres and backup CronJob |
| `pg-secret` | `metabase` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Metabase Postgres and backup CronJob |
| `cloudflared-secret` | `networking` | `TUNNEL_TOKEN` | Cloudflared tunnel |
| `vpn-secret` | app namespaces using Gluetun | Provider-specific Gluetun keys | Gluetun sidecars |
| `grafana-admin` | `monitoring` | `admin-user`, `admin-password` | Grafana |
| `aria2-secrets` | `aria2` | `ARIA2_SECRET` | Aria2 RPC |

## Target Workflow: SOPS With Age

Use SOPS with age because it works cleanly with Flux, keeps encrypted Secret
manifests in Git, and avoids introducing an external secret manager before the
homelab needs one.

Target repo shape:

```text
.sops.yaml
apps/<app>/overlays/<env>/secret.sops.yaml
infra/<component>/secret.sops.yaml
```

Target Flux shape:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

The `sops-age` Secret must live in `flux-system` and contain the private age
key. Do not commit the private key.

## Implementation Steps

1. Generate or choose an age recipient for the cluster.
2. Add `.sops.yaml` with path rules for `*.sops.yaml`.
3. Create `flux-system/sops-age` out-of-band with the private age key.
4. Add Flux `spec.decryption` to the cluster Kustomizations that need encrypted
   Secrets.
5. Convert one low-risk Secret first, for example `aria2-secrets`.
6. Reconcile Flux and verify the live Secret is created with the expected keys.
7. Convert database, Cloudflared, VPN, and Grafana Secrets after the first path
   is proven.

Example `.sops.yaml` shape:

```yaml
creation_rules:
  - path_regex: .*\.sops\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1replace_with_cluster_recipient
```

## Rotation Procedure

For a SOPS-managed Secret:

1. Generate the new credential.
2. Update the decrypted value through `sops <file>.sops.yaml`.
3. Commit and merge the encrypted diff.
4. Reconcile Flux.
5. Restart or roll workloads only when the application does not reload Secrets
   automatically.
6. Verify the application and dependent backup jobs still work.
7. Revoke the old credential at the provider or application.

For current manually managed Secrets:

1. Create the new value in the provider/application.
2. Patch or recreate the Kubernetes Secret manually.
3. Restart affected workloads if needed.
4. Record the rotation in the relevant app docs.
5. Avoid committing the value or command output containing the value.

## External Secrets Alternative

External Secrets is a reasonable future option if secrets move to a dedicated
provider such as 1Password, Vault, AWS Secrets Manager, or another central
store. It is not the first recommendation here because this homelab currently
needs GitOps reproducibility more than multi-system secret brokering.

## Current Gaps

- Secrets are not yet reproducible from Git.
- Rotation is manual and not consistently recorded per app.
- Cloudflare Access policies are outside the repo and must be verified in
  Cloudflare.
- Longhorn external backup credentials, if S3 is chosen, will need the same
  SOPS-managed Secret pattern.

Until SOPS is implemented, backup and restore manifests are reproducible but
depend on live Secrets being created manually.
