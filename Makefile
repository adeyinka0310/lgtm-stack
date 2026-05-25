.PHONY: up down restart status test-traffic chaos-errors chaos-latency chaos-cpu logs

## Start the full stack
up:
	cd /opt/lgtm-stack && docker compose start

## Stop the stack
down:
	cd /opt/lgtm-stack && docker compose stop

## Restart all services
restart:
	cd /opt/lgtm-stack && docker compose restart

## Show status of all containers
status:
	cd /opt/lgtm-stack && docker compose ps

## Generate standard test traffic (30 normal, 5 error, 3 slow)
test-traffic:
	@echo "Generating standard test traffic..."
	@for i in $$(seq 1 30); do \
		curl -s http://localhost:5000/ > /dev/null; \
		curl -s http://localhost:5000/api/data > /dev/null; \
		sleep 0.3; \
	done
	@for i in $$(seq 1 5); do \
		curl -s http://localhost:5000/error > /dev/null; \
	done
	@for i in $$(seq 1 3); do \
		curl -s http://localhost:5000/slow > /dev/null & \
	done
	@echo "Traffic generation complete"

## Game Day: Trigger error spike (raises CFR and burn rate alerts)
chaos-errors:
	@echo "Injecting error traffic for 2 minutes..."
	@end=$$((SECONDS+120)); \
	while [ $$SECONDS -lt $$end ]; do \
		curl -s http://localhost:5000/error > /dev/null; \
		sleep 0.5; \
	done
	@echo "Error injection complete"

## Game Day: Trigger latency spike
chaos-latency:
	@echo "Sending slow requests for 2 minutes..."
	@end=$$((SECONDS+120)); \
	while [ $$SECONDS -lt $$end ]; do \
		curl -s http://localhost:5000/slow > /dev/null & \
		sleep 2; \
	done
	@echo "Latency injection complete"

## Game Day: CPU pressure (requires stress tool)
chaos-cpu:
	@echo "Applying CPU pressure for 3 minutes..."
	@stress --cpu 2 --timeout 180s &
	@echo "CPU stress started — watch Prometheus for HighCPUWarning"

## Tail logs for all services
logs:
	cd /opt/lgtm-stack && docker compose logs -f --tail=50

## Check all SLI values
sli-check:
	@echo "=== Current SLI Values ==="
	@curl -s "http://localhost:9090/api/v1/query?query=sli:latency:p95_5m" | \
		python3 -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('Latency p95:', r[0]['value'][1]+'s' if r else 'no data')" 2>/dev/null
	@curl -s "http://localhost:9090/api/v1/query?query=sli:traffic:rps_5m" | \
		python3 -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('Traffic:', r[0]['value'][1]+' req/s' if r else 'no data')" 2>/dev/null
	@curl -s "http://localhost:9090/api/v1/query?query=sli:errors:ratio_5m" | \
		python3 -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('Error ratio:', r[0]['value'][1] if r else 'no data')" 2>/dev/null
	@curl -s "http://localhost:9090/api/v1/query?query=sli:saturation:cpu_5m" | \
		python3 -c "import sys,json; d=json.load(sys.stdin); r=d['data']['result']; print('CPU:', r[0]['value'][1]+'%' if r else 'no data')" 2>/dev/null

## Check firing alerts
alerts:
	@curl -s http://localhost:9090/api/v1/alerts | \
		python3 -m json.tool | grep -E '"alertname"|"state"'
