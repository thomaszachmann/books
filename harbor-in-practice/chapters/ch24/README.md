# Chapter 24 — Observability, Webhooks, and Handover

**Starting state:** Chapter 23 finished.

```bash
./observe.sh endpoints
./observe.sh events                  # reads Harbor's source, not a copy
EXPORTER_URL=http://127.0.0.1:8001/metrics ./observe.sh inventory
CORE_METRICS_URL=http://127.0.0.1:8001/metrics ./observe.sh traffic
./observe.sh audit
./webhook-listen.sh 9000
./handover.sh > HANDOVER.md
```

## Three mechanisms, three different questions

| Question | Mechanism | Where |
|---|---|---|
| How much, and is it healthy? | metrics | exporter `:8001/metrics` |
| Did something happen to an artifact? | webhooks | 10 of 19 topics |
| Who did that? | audit log | database, or forwarded |

`metrics.enabled` is **false** by default and turns on all four
endpoints — core, registry, jobservice, exporter — on port 8001. The
split worth knowing: the **exporter** gives inventory
(`harbor_project_quota_usage_byte`, `harbor_task_queue_size`,
`harbor_health`), **core** gives traffic
(`harbor_core_http_request_total{method,code,operation}`).

## Ten webhook events out of nineteen topics

`observe.sh events` computes the difference from Harbor's source at the
pinned tag, so it cannot drift from the book quietly:

```
webhook events:  10
no webhook, audit log only:
  ARTIFACT_LABELED COMMON_API
  CREATE_PROJECT CREATE_ROBOT CREATE_TAG
  DELETE_PROJECT DELETE_REPOSITORY DELETE_ROBOT DELETE_TAG
```

Every project, repository, tag and robot creation and deletion is in the
right-hand column. Those are the events people want alerts on, and the
list is fixed in the code. `COMMON_API` is the generic topic that feeds
the audit log — which is the design, not an omission.

## Three seconds, three attempts

```yaml
notification:
  webhook_job_max_retry: 3
  webhook_job_http_client_timeout: 3
```

`webhook-listen.sh` answers before it prints, which is the shape every
receiver needs. A receiver that works before responding gets retried and
then dropped, and Harbor does not say it gave up.

## The audit log fallback that hides itself

Forwarding is syslog over TCP. If the dial fails, Harbor logs **one**
error and writes the audit records to core's stdout instead. With
`skip_audit_log_database: true` — which is what you set once the syslog
collector is the system of record — the compliance trail becomes
container logs, silently, the first time the collector restarts.

`observe.sh audit` probes the endpoint and exits non-zero when it is
unreachable. Monitor the collector, not Harbor.

Also: `pull_audit_log_disable`. A row per pull makes the audit table the
largest thing in the database, which is what makes Chapter 23's schema
migration slow.

## The handover

`handover.sh` reads the live configuration and emits the eight questions
with the answers it can find and blanks for the rest. The blanks are the
deliverable.
