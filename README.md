# LGTM Observability Stack

A production-grade observability stack built with Prometheus, Loki, Grafana,
and Tempo — fully provisioned as code with SLOs, error budgets, DORA metrics,
and automated alerting.

---

## One-command deployment

```bash
git clone https://github.com/adeyinka0310/lgtm-stack.git
cd lgtm-stack
docker compose up -d
```

---

## Stack components

| Service | Port | Purpose |
|---|---|---|
| Grafana | 3000 | Unified dashboards |
| Prometheus | 9090 | Metrics storage (30d retention) |
| Loki | 3100 | Log storage (30d retention) |
| Tempo | 3200 | Trace storage (30d retention) |
| Alertmanager | 9093 | Alert routing |
| Node Exporter | 9100 | System metrics |
| Blackbox Exporter | 9115 | HTTP/SSL probing |
| OTel Collector | 4319/4320 | Telemetry pipeline |
| DORA Collector | 8090 | Deployment metrics |
| Demo App | 5000 | Instrumented service |

---

## Default credentials

Grafana: admin / admin123 — change immediately in production

---

## Four Golden Signals (SLIs)

### Signal 1 — Latency

How long does it take to serve a request?

PromQL:
  histogram_quantile(0.95,
    sum by(le) (
      rate(flask_http_request_duration_seconds_bucket{status="200"}[5m])
    )
  )

SLO target: 95% of requests complete under 500ms

### Signal 2 — Traffic

How much demand is the system handling?

PromQL:
  sum(rate(flask_http_request_total[5m]))

SLO target: Informational — used for capacity planning

### Signal 3 — Errors

What fraction of requests are failing?

PromQL:
  sum(rate(flask_http_request_total{status=~"5.."}[5m]))
  /
  sum(rate(flask_http_request_total[5m]))

SLO target: 99% of requests succeed (error rate under 1%)

### Signal 4 — Saturation

How full is the system?

PromQL:
  100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
  1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})

SLO target: CPU below 80%, memory below 80%, disk below 75%

---

## SLO Targets

| SLO | Target | Window | Error Budget |
|---|---|---|---|
| Availability | 99.5% | 30 days | 216 minutes downtime allowed |
| Latency | 95% under 500ms | 30 days | 5% of requests may be slow |
| Error Rate | 99% success | 30 days | 432 minutes equivalent |
| Probe Uptime | 99.5% | 30 days | 216 minutes downtime allowed |

### Rationale

- 99.5% availability chosen over 99.9% because 99.9% allows only 43 minutes
  per month — too strict for a small team without on-call automation.
- 500ms latency threshold is where users notice slowness. Under 200ms feels
  instant, 200-500ms is acceptable, above 500ms causes user frustration.
- 95th percentile chosen so occasional slow outliers do not burn the budget.

---

## Error Budget Policy

| Budget consumed | Action |
|---|---|
| 50% (108 min) | Prioritise reliability work, review recent incidents |
| 75% (162 min) | Feature freeze for this service |
| 100% (216 min) | Full reliability sprint, executive notification |

Burn rate alerts:

| Alert | Condition | Meaning | Action |
|---|---|---|---|
| FastBurn critical | 14.4x burn for 5m | Budget gone in 2 days | Page on-call immediately |
| SlowBurn warning | 5x burn for 15m | Budget gone in 6 days | Investigate within 4 hours |

---

## DORA Metrics

| Metric | DORA Benchmarks |
|---|---|
| Deployment Frequency | Elite: multiple/day, High: weekly, Medium: monthly, Low: less |
| Lead Time for Changes | Elite: under 1hr, High: under 1day, Medium: under 1wk, Low: over 1wk |
| Change Failure Rate | Elite: under 5%, High: under 10%, Medium: under 15%, Low: over 15% |
| Mean Time to Restore | Elite: under 1hr, High: under 1day, Medium: under 1day, Low: over 1day |

### Game Day results

| Scenario | Trigger | Observed | Alert fired |
|---|---|---|---|
| Deployment failure | 2 bad deployments injected | CFR reached 33.3% | HighChangeFailureRate |
| Latency injection | /slow endpoint flooded | p95 jumped to 2.35s, 48.8% under 500ms | SLO latency degraded |
| CPU pressure | stress --cpu 2 for 3min | CPU 3.7% to 23.8% | HighCPUWarning fired |

---

## Alert Rules (version-controlled)

All alert rules live in config/prometheus/rules/ and are never configured
via the Grafana UI.

### Infrastructure alerts

| Alert | Condition | Severity |
|---|---|---|
| HighCPUWarning | CPU above 80% for 5m | warning |
| HighCPUCritical | CPU above 90% for 10m | critical |
| HighMemoryWarning | Memory above 80% for 5m | warning |
| HighMemoryCritical | Memory above 90% for 5m | critical |
| DiskSpaceWarning | Disk above 75% for 5m | warning |
| DiskSpaceCritical | Disk above 90% for 5m | critical |
| ServerDown | Blackbox probe fails for 2m | critical |

### SLO burn rate alerts

| Alert | Condition | Severity |
|---|---|---|
| AvailabilitySLOFastBurn | 14.4x burn rate for 5m | critical |
| AvailabilitySLOSlowBurn | 5x burn rate for 15m | warning |

### DORA alerts

| Alert | Condition | Severity |
|---|---|---|
| HighChangeFailureRate | CFR above 15% for 5m | warning |

### Alertmanager routing

- All alerts route to #DevOps-Alerts in Slack
- Critical alerts: group_wait 10s, repeat every 1h
- Warning alerts: group_wait 60s, repeat every 4h
- Inhibition: CPU/memory/latency alerts suppressed when host is fully down

---

## Dashboards

All dashboards provisioned via JSON in config/grafana/dashboards/.
Never manually configured in the Grafana UI.

| Dashboard | UID | Contents |
|---|---|---|
| DORA Metrics | dora-metrics | Deployment frequency, CFR, lead time, MTTR |
| SLO & Error Budget | slo-dashboard | SLI gauges, burn rate, latency p95/p99 |
| Node Exporter | node-exporter | CPU, memory, disk I/O, network, load average |
| Blackbox Exporter | blackbox-dashboard | Uptime, response time, SSL expiry |
| Unified Observability | unified-dashboard | Metrics + logs + traces drill-down |

### Unified Observability drill-down

1. Spot a metric spike in the error rate or latency panel
2. Click through to Loki to see logs from that exact time window
3. Click a trace_id in the logs to open the trace directly in Tempo
4. Identify the exact service and endpoint responsible

---

## Runbooks

| Alert | Runbook |
|---|---|
| HighCPUWarning / HighCPUCritical | runbooks/high-cpu.md |
| HighMemoryWarning / HighMemoryCritical | runbooks/high-memory.md |
| DiskSpaceWarning / DiskSpaceCritical | runbooks/disk-space.md |
| ServerDown | runbooks/server-down.md |
| AvailabilitySLOFastBurn | runbooks/slo-fast-burn.md |
| AvailabilitySLOSlowBurn | runbooks/slo-slow-burn.md |

Post-Incident Review: runbooks/post-incident-review.md

---

## Toil identified

### Toil 1 — Manual MTTR recording
Current: engineer manually POSTs incident duration to DORA collector after each incident.
Cost: 5 minutes per incident, frequently forgotten, inaccurate.
Proposed: Alertmanager resolved webhook automatically calls DORA collector.
Status: Planned for next sprint.

### Toil 2 — Manual test traffic generation
Current: engineer runs curl loops to generate SLI test data.
Cost: 15 minutes per test cycle, not reproducible across engineers.
Proposed: make test-traffic runs a standardised load profile from CI.
Status: Implemented — see Makefile.

---

## Makefile commands

  make up             # Start the full stack
  make down           # Stop the stack
  make restart        # Restart all services
  make status         # Show container status
  make test-traffic   # Generate standard test traffic
  make chaos-errors   # Game Day: inject error spike
  make chaos-latency  # Game Day: inject latency spike
  make chaos-cpu      # Game Day: apply CPU pressure
  make sli-check      # Print current SLI values
  make alerts         # Show all firing alerts
  make logs           # Tail logs for all services

---

## Retention periods

| Data type | Retention | Where configured |
|---|---|---|
| Metrics | 30 days | Prometheus --storage.tsdb.retention.time=30d |
| Logs | 30 days | Loki limits_config.retention_period: 720h |
| Traces | 30 days | Tempo compactor.compaction.block_retention: 720h |

---

## Why LGTM over managed alternatives

Managed alternatives (Datadog, New Relic, Grafana Cloud) cost $20-200 per
host per month and create vendor lock-in. The LGTM stack runs on any Linux
server, costs only compute, and gives full control over retention, alerting
logic, and data ownership. The open source ecosystem means every component
has extensive documentation and community support.

The tradeoff is operational overhead — you manage the stack yourself.
This project demonstrates that with Docker Compose and Infrastructure as Code,
that overhead is manageable and the learning value is significant.

---

## How the Four Golden Signals go beyond CPU and RAM

CPU and RAM are saturation metrics — they tell you the system is struggling
but not why users are affected. The Four Golden Signals connect infrastructure
health directly to user experience:

- Latency tells you whether users are waiting too long
- Traffic tells you whether demand has changed (spike = likely cause)
- Errors tells you whether users are getting failures, not just slowness
- Saturation tells you how close you are to the limit

A server at 90% CPU with 0% errors and 50ms latency is fine.
A server at 30% CPU with 10% errors and 2s latency is on fire.
CPU and RAM alone would miss the second scenario entirely.

---

## How DORA metrics connect to business outcomes

| DORA metric | Business outcome |
|---|---|
| Deployment Frequency | How fast can we deliver value to users? |
| Lead Time for Changes | How long from idea to production? |
| Change Failure Rate | How often do we break things for users? |
| Mean Time to Restore | How quickly do we recover when we break things? |

Elite performers deploy multiple times per day with under 5% failure rate
and recover in under an hour. This directly correlates with higher revenue,
market share, and employee satisfaction per the DORA State of DevOps report.

---

## How burn rate alerting reduces alert fatigue

Traditional threshold alerts (CPU above 80%) fire constantly on spikes and
create noise that engineers learn to ignore. Burn rate alerts ask a different
question: at the current rate of failure, will we exhaust the error budget
before the window ends?

A 14.4x burn rate means the budget will be gone in 2 days instead of 30.
That is worth waking someone up. A 1x burn rate is exactly on target —
no alert needed. Alerts only fire when there is a genuine reliability
problem, not a momentary spike.

Multi-window alerting (1h fast burn + 6h slow burn) catches both sudden
outages and slow degradations that would otherwise go unnoticed until the
budget is nearly exhausted.

---

## Post-Incident Review

See runbooks/post-incident-review.md for a full blameless PIR documenting
the AvailabilitySLOFastBurn incident, including full timeline, root cause,
impact, what went well, what went wrong, and action items with owners
and due dates.

---

## Repository structure

  lgtm-stack/
  ├── docker-compose.yml
  ├── Makefile
  ├── ERROR_BUDGET_POLICY.md
  ├── README.md
  ├── .github/workflows/deploy.yml
  ├── config/
  │   ├── prometheus/
  │   │   ├── prometheus.yml
  │   │   ├── blackbox.yml
  │   │   └── rules/
  │   │       ├── infrastructure.yml
  │   │       ├── sli-slo.yml
  │   │       ├── slo-definitions.yml
  │   │       └── dora.yml
  │   ├── loki/loki.yml
  │   ├── tempo/tempo.yml
  │   ├── alertmanager/
  │   │   ├── alertmanager.yml
  │   │   └── templates/slack.tmpl
  │   ├── otel-collector/otel-collector.yml
  │   └── grafana/
  │       ├── provisioning/datasources/datasources.yml
  │       ├── provisioning/dashboards/dashboards.yml
  │       └── dashboards/
  │           ├── dora.json
  │           ├── slo.json
  │           ├── node-exporter.json
  │           ├── blackbox.json
  │           └── unified.json
  └── runbooks/
      ├── high-cpu.md
      ├── high-memory.md
      ├── disk-space.md
      ├── server-down.md
      ├── slo-fast-burn.md
      ├── slo-slow-burn.md
      └── post-incident-review.md
