# Error Budget Policy

## SLO Targets

| SLO | Target | Window | Error Budget |
|-----|--------|--------|-------------|
| Availability | 99.5% | 30 days | 216 minutes downtime |
| Latency | 95% under 500ms | 30 days | 5% of requests may be slow |
| Error Rate | 99% success | 30 days | 432 minutes equivalent |
| Probe Uptime | 99.5% | 30 days | 216 minutes downtime |

## Rationale

- **99.5% availability** chosen over 99.9% because this is a non-critical demo
  service. 99.9% allows only 43 minutes/month — too strict for a small team.
- **500ms latency** is the threshold where users notice slowness (research
  shows <200ms feels instant, 200-500ms is acceptable, >500ms causes frustration).
- **95th percentile** chosen so occasional slow outliers don't burn the budget.

## Error Budget Consumption Thresholds

### 50% consumed (108 minutes used)
- Engineering lead notified
- Feature work continues but reliability improvements are prioritised
- On-call reviews recent incidents for patterns
- Post-incident review required for any incident >30 minutes

### 75% consumed (162 minutes used)
- Feature freeze for the service
- All engineering effort redirected to reliability
- Daily SLO review meeting
- SRE team lead escalated

### 100% consumed (216 minutes used)
- Full reliability sprint — no new features until budget recovers
- Incident commander assigned
- Executive notification
- SLO target under review — may need to be revised down

## Burn Rate Alerts

| Alert | Condition | Meaning | Action |
|-------|-----------|---------|--------|
| FastBurn (critical) | 14.4x burn rate for 5m | Budget gone in ~2 days | Page on-call immediately |
| SlowBurn (warning) | 5x burn rate for 15m | Budget gone in ~6 days | Investigate within 4 hours |

## SLO Review Cadence

- **Weekly**: On-call team reviews current budget remaining
- **Monthly**: Full SLO review — are targets still appropriate?
- **Quarterly**: Business stakeholder review — do SLOs match user expectations?

## Decision Authority

| Decision | Owner |
|----------|-------|
| Declare reliability sprint | Engineering Lead |
| Revise SLO targets | Engineering Lead + Product Manager |
| Override feature freeze | VP Engineering only |
