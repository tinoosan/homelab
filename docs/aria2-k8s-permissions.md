# Aria2 in Kubernetes — UID/GID & Permissions Gotchas

## Symptoms we hit
- Aria2 pod starts but RPC 6800 is closed or init fails.
- Logs full of Permission denied / Operation not permitted during s6 init:
  - groupmod: Permission denied
  - ln: /etc/localtime: Permission denied
  - s6-chown/s6-chmod: Operation not permitted
- When it does start, downloads fail writing to `/data/...` with:
  - Failed to make the directory ... Permission denied
- RPC works locally, but K8s pod returns 401/400 (separate auth/WS issue; out of scope here).

## Root causes
1. Image expects root during init.
   - `ghcr.io/p3terx/aria2-pro` uses s6 init scripts that `chown`/`chmod` under `/var/run/s6/etc` and tweak `/etc/*`.
   - If the container is forced non-root (via `securityContext.runAsUser` or `PUID/PGID` env), those steps fail and the service may not bind `:6800`.
2. hostPath ownership doesn’t match the container user.
   - We mount the host’s `/media` to `/data` in the pod. The directory was `root:root` with `0755`.
   - Aria2 (running as non-root) couldn’t create subdirs/files under `/data`.
3. Env vs effective user mismatch.
   - Setting `PUID/PGID=65532` while the container is actually UID 0 (or vice versa) leads to confusing behavior: the process might run, but created files or permission checks don’t match expectations.

## What fixed it (two viable patterns)

### Pattern A — “Let init run as root, then drop”

Use the image defaults (no forced non-root). The s6 scripts run as root, then aria2 drops privileges internally per image defaults/`PUID/PGID`.

- K8s Deployment (do not set `securityContext.runAsUser/runAsGroup`):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aria2
spec:
  replicas: 1
  selector:
    matchLabels: { app: aria2 }
  template:
    metadata:
      labels: { app: aria2 }
    spec:
      containers:
        - name: aria2
        image: ghcr.io/p3terx/aria2-pro:latest
          env:
            - name: RPC_SECRET     # from Secret in your cluster
              valueFrom:
                secretKeyRef:
                  name: torrus-secrets
                  key: ARIA2_SECRET
            - name: RPC_LISTEN_ALL
              value: "true"
            # Optional: pick a non-root UID/GID for the aria2 *service* (after init)
            - name: PUID
              value: "1000"
            - name: PGID
              value: "1000"
            - name: UMASK_SET
              value: "022"
          volumeMounts:
            - name: aria2-data
              mountPath: /data
      volumes:
        - name: aria2-data
          hostPath:
            path: /media     # host folder for downloads
            type: Directory
```

- On the node, ensure the host path is writeable by that UID/GID:

```bash
sudo mkdir -p /media
sudo chown -R 1000:1000 /media
sudo chmod 775 /media
```

If you set `PUID/PGID=0` (root) you don’t need to `chown`, but non-root is safer.

### Pattern B — Keep pod non-root, but prep the mount

If your policy enforces non-root at the pod level:

- Run an initContainer once to `chown` the mounted path:

```yaml
spec:
  initContainers:
    - name: fix-perms
      image: busybox:1.36
      command: ["sh","-lc","chown -R 1000:1000 /data && chmod -R 775 /data"]
      securityContext:
        runAsUser: 0   # just for the chown
      volumeMounts:
        - name: aria2-data
          mountPath: /data
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000          # helps for some volume types; for hostPath you still need chown
  containers:
    - name: aria2
      image: ghcr.io/p3terx/aria2-pro:latest
      env:
        - name: PUID
          value: "1000"
        - name: PGID
          value: "1000"
      volumeMounts:
        - name: aria2-data
          mountPath: /data
  volumes:
    - name: aria2-data
      hostPath:
        path: /media
        type: Directory
```

## Verification commands

From the node (host):

```bash
sudo ls -ld /media
sudo stat -c 'mode=%a owner=%u:%g %n' /media
```

From inside the aria2 container:

```bash
kubectl -n torrus-dev exec -it deploy/aria2 -c aria2 -- sh -lc '
id; whoami || true;
ls -ld /data; mkdir -p /data/.probe && touch /data/.probe/ok && ls -l /data/.probe
'
```

Expected: the touch succeeds and the file owner matches your `PUID/PGID` decision.

Service reachability (ClusterIP):

```bash
kubectl -n torrus-dev run curlcheck --rm -it --image=curlimages/curl:8.8.0 --restart=Never -- \
sh -lc 'curl -sS -H "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"id\":\"x\",\"method\":\"aria2.getVersion\",\"params\":[\"token:$(kubectl -n torrus-dev get secret torrus-secrets -o jsonpath={.data.ARIA2_SECRET} | base64 -d)\"]}" \
  http://aria2:6800/jsonrpc'
```

Expected JSON: `result.version` present (not Unauthorized).

## Gotchas to document
- Don’t force non-root via `securityContext` on this image unless you also handle init needs (initContainer or host prep).
- For `hostPath`, Kubernetes won’t fix ownership for you. You must `chown` on the host or in an initContainer.
- `fsGroup` helps only where the volume driver supports it; `hostPath` often ignores it.
- If using `PUID/PGID`, make the host folder’s owner/group match those values, or at least grant group `rwx` (e.g., 775) and set the folder’s group accordingly.
- When debugging write failures, test from inside the container (see commands above) to separate K8s networking from filesystem permissions.
- Keep `UMASK_SET=022` (or your policy) so created files are readable by Plex/NFS consumers.

## Minimal checklist for future PRs
- Decide on runtime user (root-init → drop to 1000:1000 or strict non-root with initContainer chown).
- Ensure `/data` mount is writeable by that user (owner or group).
- Verify with an in-pod touch test.
- Confirm RPC is live with a tokened `aria2.getVersion`.
- (If notifications used) confirm WS subprotocol `jsonrpc` is set in the client.

That’s it—drop this in the docs and you’ll save the next person a couple of hours.
