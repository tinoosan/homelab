# How private PDF processing works

Stirling PDF runs PDF operations on Mugiwara instead of sending documents to a
public converter. Open it at
[Stirling PDF](https://mugiwara.tail9aaa00.ts.net:8453/). This deployment is for
interactive editing, conversion, OCR, redaction and signing. It is not the
long-term home for the resulting documents.

## Follow one request

Your browser connects to the host through the tailnet. Tailscale terminates HTTPS
on port 8453 and proxies the request to `127.0.0.1:8084`. Docker forwards that
loopback port to Stirling PDF on container port 8080.

| Step | Connection | Purpose |
|---|---|---|
| 1 | Browser to `mugiwara.tail9aaa00.ts.net:8453` | Encrypted private access |
| 2 | Tailscale Serve to `127.0.0.1:8084` | HTTPS termination and local proxying |
| 3 | Docker port 8084 to container port 8080 | Deliver the request to Stirling PDF |

Binding Docker to `127.0.0.1` matters. It keeps port 8084 off the LAN while still
letting the local Tailscale process reach it. Stirling PDF also requires its own
login, so a tailnet connection alone does not grant access to document tools.

Executor reaches the same service through its MCP endpoint at `/mcp`. That path
uses a per-user API key in the `X-API-KEY` header. Executor stores the credential
encrypted and exposes eight grouped Stirling tools to MCP clients. An anonymous
MCP request is rejected even from inside the tailnet.

```text
MCP client -> Executor :8446/mcp -> Stirling :8453/mcp
                                      X-API-KEY
```

The MCP client first proves it may use Executor. Executor then proves it may use
Stirling. The browser login still protects the interactive Stirling interface.

## Read the Compose file

The live configuration is `~/services/stirling-pdf/compose.yaml`. The image uses
an immutable digest, so recreating the container runs the same build until the
Compose file is deliberately updated. `restart: unless-stopped` brings the
service back after a host reboot unless an operator stopped it.

The three bind mounts have different jobs:

| Host path | Container path | What survives recreation |
|---|---|---|
| `data/configs/` | `/configs` | Application settings and local state |
| `data/tessdata/` | `/usr/share/tessdata` | OCR language files |
| `data/logs/` | `/logs` | Application logs |

Uploaded PDFs are working data. The service may use temporary storage while it
processes a file, then the browser downloads the result. Put documents that need
long-term storage in Nextcloud or another managed location.

## Why there is no public route

PDFs often contain names, addresses, signatures and account details. A tailnet
route keeps the editor reachable from authorised devices without publishing an
internet endpoint. The application login adds another boundary for devices on
the tailnet. Disabling metrics and the survey also removes two features this
private single-host deployment does not need.

`MCP_ENABLED=true` turns on the automation endpoint. `MCP_AUTH_MODE=apikey`
requires a Stirling user API key. The current key is kept in Executor's private
service directory and must never be copied into this handbook or the Compose
file.

## Operate the service

Run these commands from the service directory:

```bash
cd ~/services/stirling-pdf
docker compose ps
docker compose logs --tail 50
docker compose restart
docker compose stop
docker compose up -d
```

`ps` shows the container and health state. Logs explain startup or conversion
failures, but may mention filenames, so review them before sharing. `stop` keeps
the bind-mounted state. Avoid `down -v` as a routine command, even though this
deployment currently uses bind mounts rather than named volumes.

## Update it deliberately

Pull the intended version, inspect its digest, replace the digest in
`compose.yaml`, then recreate the service:

```bash
docker pull docker.stirlingpdf.com/stirlingtools/stirling-pdf:VERSION
docker image inspect docker.stirlingpdf.com/stirlingtools/stirling-pdf:VERSION \
  --format '{{json .RepoDigests}}'
docker compose up -d
docker compose ps
```

Test at least one representative operation after an update. Opening the home
page proves routing and startup, but it does not prove that OCR, conversion or
document download works.

## Diagnose failures

If the URL does not open, check the layers in order:

```bash
docker compose ps
curl -fsS http://127.0.0.1:8084/api/v1/info/status
tailscale serve status
```

An unhealthy container points to Stirling PDF or its mounted directories. A
successful local status request with a broken HTTPS URL points to Tailscale Serve
or the client device's tailnet connection. If one PDF operation fails while the
status endpoint works, inspect the container logs and test a small non-sensitive
file to separate an application problem from a malformed or encrypted document.

For automation failures, check the connection in Executor as well. A healthy
Stirling container proves the server is running; a healthy Executor connection
also proves that the stored key can initialize an MCP session and discover tools.

## Check your understanding

- Why does binding to `127.0.0.1` still permit access through Tailscale Serve?
- Which directories must survive container replacement?
- Why is a successful health check weaker evidence than a completed PDF edit?
- Why do the Executor and Stirling authentication checks protect different hops?
- Where should the finished document live after processing?

Further reading: [official Docker installation](https://docs.stirlingpdf.com/Installation/Docker%20Install/).
