# Docker media services on Mugiwara

Updated 2026-09-20. Docker is the authoritative state for Homarr, Sonarr,
Prowlarr, Radarr and Transmission. Their Kubernetes manifests, namespaces,
Longhorn volumes and public tunnel routes are retired. No migration backups
or parallel rollback installations are retained. Existing application backup
schedules are separate from migration copies and remain unchanged.

## Access and versions

Connect the viewing device to the tailnet. These HTTPS routes use Tailscale
Serve, not Funnel. Mugiwara must remain running and connected.

| Service | Private URL | Host-loopback port | Version |
| --- | --- | --- | --- |
| Homarr | https://mugiwara.tail9aaa00.ts.net/ | 7575 | 1.77.2 |
| Sonarr | https://mugiwara.tail9aaa00.ts.net:8449/ | 8989 | 4.0.20.3014 |
| Prowlarr | https://mugiwara.tail9aaa00.ts.net:8450/ | 9696 | 2.5.2.5491 |
| Transmission | https://mugiwara.tail9aaa00.ts.net:8451/ | 9091 | 4.1.1 |
| Radarr | https://mugiwara.tail9aaa00.ts.net:8452/ | 7878 | 6.4.4.10685 |

Homarr links to each service. Existing Homarr and Arr application accounts
are retained. Transmission retains its existing unauthenticated RPC setting;
its published port binds only to loopback and its HTTPS route is tailnet-only.

## Configuration and data

The live Compose files on Mugiwara are:

- `/home/tinoosan/services/arr/compose.yaml` for the media services.
- `/home/tinoosan/services/homarr/compose.yaml` for the dashboard.

Images are pinned by digest. Live data is outside this Git repository:

| Path under `/home/tinoosan/services/arr` | Purpose |
| --- | --- |
| `sonarr/` | Sonarr database and settings, 48 series at migration |
| `radarr/` | Radarr database and settings, 83 movies at migration |
| `prowlarr/` | Indexers and application integrations |
| `transmission/` | Settings, torrent metadata and resume state |
| `gluetun/` | VPN runtime data |
| `secrets/openvpn_user`, `secrets/openvpn_password` | Existing NordVPN service credentials, Docker secrets |
| `resolv.conf` | Resolver at `127.0.0.1` in the shared VPN namespace |

Keep the secrets private. The secret files have mode 600 and their directory
has mode 700. Do not commit application databases, API keys or credentials.
Homarr keeps its live database in `appdata/` and its encryption key in `.env`
under its service directory. Preserve that key.

Sonarr and Radarr run with UID 1000 and GID 959. Prowlarr and Transmission
use UID/GID 1000. Sonarr and Radarr preserve these existing bind mounts:

| Host path | Container path |
| --- | --- |
| `/mnt/gdrive/Videos/tv` | `/media/tv` |
| `/mnt/gdrive/Videos/movies` | `/media/movies` |
| `/mnt/gdrive/Videos/anime` | `/media/anime` |
| `/downloads` | `/downloads` |

Transmission shares `/downloads`, so no remote-path translation is needed.
Radarr's movie root remains `/media/movies/`. Media still depends on
`rclone-gdrive.service`; this migration moved application state, not media.
Mount the rclone filesystem before starting the stack. After a remount,
recreate Sonarr and Radarr so they see the current filesystem. Bind mounts
use `create_host_path: false` to avoid silently creating missing directories.

## VPN and service connections

Homarr joins the `arr_default` Docker network so its server-side integrations
can reach Sonarr, Radarr and Prowlarr through `gluetun` on ports 8989, 7878 and
9696. Their API keys remain encrypted in Homarr's database. The dashboard links
each integration to its existing browser-facing app tile and uses them in the
calendar, missing-media and indexer widgets.

The Gluetun integration uses the control server on port 8000. Its
`gluetun-auth/config.toml` role permits only the four GET routes required by
Homarr's VPN widget. VPN-control PUT routes remain unavailable to Homarr.

Sonarr, Radarr, Prowlarr, Transmission and FlareSolverr share Gluetun's network
namespace. They have no independent Docker network connection. Gluetun 3.41.3
uses NordVPN OpenVPN at `nl912.nordvpn.com` in the Netherlands. Its firewall
is enabled, with no outbound LAN or Kubernetes subnet exceptions. UI ports
7878, 8989, 9696 and 9091 are published only on host loopback.

Radarr and Sonarr trust forwarded headers only from `172.25.0.1/32`, the
Docker bridge gateway used by host-side Tailscale Serve. Authentication remains
required. This preserves HTTPS on login redirects. If the Compose network is
recreated with a different gateway, update Trusted Networks in both apps to
the new gateway address only. See the [Radarr security settings](https://github.com/Servarr/Wiki/blob/master/radarr/settings.md#security).

DNS resolves through Gluetun at `127.0.0.1`, with DNS over TLS upstream.
Applications wait for VPN health on startup. Gluetun handles tunnel reconnects.
If the pinned VPN endpoint is retired, change `SERVER_HOSTNAMES` and verify
VPN health and egress before resuming normal use.

Inside the shared namespace:

- Prowlarr connects to Sonarr at `http://127.0.0.1:8989` and Radarr at
  `http://127.0.0.1:7878`.
- Both applications reach Prowlarr at `http://127.0.0.1:9696`.
- Both use Transmission RPC at `127.0.0.1:9091`, path `/transmission/`.
- Prowlarr's FlareSolverr proxy uses `http://127.0.0.1:8191`.
  FlareSolverr has no published host port.

Prowlarr synchronizes compatible indexers to each application. Five enabled
indexers passed connection tests: Nyaa.si, showRSS, The Pirate Bay,
TorrentDownload and YTS. Radarr receives the four movie-compatible indexers.
EZTV is disabled because it returned HTTP 451 through FlareSolverr.
TorrentGalaxyClone was removed because its definition was unavailable.

## Operations

Run commands from the live service directory:

```sh
cd /home/tinoosan/services/arr
docker compose ps
docker compose logs --tail 50 radarr gluetun
docker compose up -d
```

Containers use `restart: unless-stopped`. To stop the stack deliberately:

```sh
docker compose stop
```

When changing Gluetun networking or its image, recreate all dependent
containers together so they share the new network namespace:

```sh
docker compose up -d --force-recreate
```

For a Radarr-only image update, pull the desired image, record its immutable
digest in `compose.yaml`, then run:

```sh
docker compose up -d radarr
```

Check System > Status and System > Health, movie count, root-folder access,
download-client test, and Prowlarr application test after an update.
The small local `api.py` helper reads API keys from each application's
`config.xml`; do not print those keys or copy them into documentation.

Inspect private routing with `tailscale serve status`. Restore just Radarr's
route with:

```sh
tailscale serve --bg --https=8452 http://127.0.0.1:7878
```

Remove just that route with `tailscale serve --https=8452 off`. Do not reset
all Serve routes, because the host also serves other private applications.
Homarr operations use the same Compose commands in its own directory.

## Migration checks and known state

Radarr's database integrity check passed before startup. All 83 movies and
the existing account settings were retained. Radarr runs version 6.4.4.10685.
Transmission and Prowlarr integration tests passed. Movie and download paths
are writable by the runtime user. Radarr egress reports the Netherlands. All four Radarr indexer tests passed
and its refreshed health check was empty. Flux applied the retirement commit;
the old Radarr namespace, Longhorn volume, PV and attachment are removed.

Previous Sonarr/Prowlarr tests confirmed that stopping Gluetun blocks direct-IP
HTTPS on both the default route and forced eth0. All media applications now
share that same firewall namespace. Direct traffic forced through eth0 is
also checked after migration. Private HTTPS and authenticated APIs are checked
from Mugiwara; this is not a visual browser test on another device.

Four retained Transmission queue entries reported missing local data and were
left stopped. They were not deleted or restarted. Review their paths if those
files are wanted. Always Sunny S18E06 was already present in the media library.

Git and Flux manage the remaining Kubernetes services. They do not manage this
Docker stack. Historical dated audits describe the cluster at their audit date;
this runbook describes the migrated services' current setup.
