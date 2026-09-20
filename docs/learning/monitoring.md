# How monitoring works

Monitoring answers questions that a current-status dashboard cannot: when a
resource problem began, whether it is getting worse, and which service changed
at the same time. Mugiwara runs a small Docker monitoring stack under
`~/services/monitoring`.

Open [Grafana](https://mugiwara.tail9aaa00.ts.net:8454/) for dashboards and
[Prometheus](https://mugiwara.tail9aaa00.ts.net:8455/) for targets and raw metric
queries. Both routes are private to the tailnet.

## Follow one measurement

```text
Linux host ----> Node Exporter --+
                               +--> Prometheus --> Grafana
Docker engine -> cAdvisor ------+
```

Node Exporter reads Linux counters such as CPU time, available memory and
filesystem space. cAdvisor reads container cgroups and Docker metadata.
Prometheus requests each exporter's `/metrics` endpoint every 15 seconds and
stores the resulting time series. Grafana queries that history and renders it.

Grafana does not collect measurements itself. If a panel is empty, first check
the corresponding target in Prometheus rather than changing the panel.

## Read the Compose stack

The live Compose file defines four containers:

| Container | Responsibility | Host port |
|---|---|---|
| Prometheus | Scrape and retain metrics | `127.0.0.1:9090` |
| Grafana | Dashboards and login | `127.0.0.1:3000` |
| Node Exporter | Host metrics | none |
| cAdvisor | Docker container metrics | none |

Only the two user interfaces publish ports, and those ports bind to loopback.
Tailscale Serve terminates private HTTPS on ports 8454 and 8455. The exporters
remain inside the Compose network.

cAdvisor needs read-only access to Docker and host accounting paths. It runs as
a privileged container because those kernel views are otherwise incomplete.
Treat it as infrastructure software and keep its UI unexposed. The host's
`fs.inotify.max_user_instances` value is 1024 so cAdvisor can watch the large
number of mounts created by Docker and the remaining Kubernetes workloads.

## Storage and retention

Prometheus keeps at most 30 days or 10 GB of samples, whichever limit is reached
first. Its data lives in `monitoring_prometheus_data`. Grafana users, preferences
and UI changes live in `monitoring_grafana_data`.

The Prometheus data source and **Mugiwara overview** dashboard are provisioned
from files in `~/services/monitoring/grafana`. This makes the useful starting
view reproducible while still allowing additional dashboards in Grafana.

## Operate and diagnose it

Run commands from `~/services/monitoring`:

```bash
docker compose ps
docker compose logs --tail 50
docker compose restart
docker compose up -d
```

Prometheus shows `prometheus`, `mugiwara` and `docker` on its **Targets** page.
All three should be `UP`. Their meanings narrow failures:

- `prometheus` down means the collector cannot scrape itself or its configuration is invalid.
- `mugiwara` down points to Node Exporter or the Compose network.
- `docker` down points to cAdvisor, Docker access or host watcher limits.

Grafana's **Mugiwara overview** should show host CPU, memory, root-disk use,
container count and per-container history. A working Grafana login with empty
panels usually means the data source or Prometheus target is unhealthy.

## Check your understanding

- Why can Grafana be healthy while every dashboard panel is empty?
- Which exporter owns host filesystem metrics?
- Why are the exporter ports not published on the host?
- What happens first when Prometheus reaches its time or size retention limit?
