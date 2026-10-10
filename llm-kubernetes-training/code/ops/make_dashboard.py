#!/usr/bin/env python3
"""Erzeugt das Grafana-Dashboard "KI-Plattform" (Tag 15) als JSON auf stdout."""
import json

# (Titel, PromQL, Einheit, Legende)
PANELS = [
    ("GPU-Auslastung", "avg by (Hostname) (DCGM_FI_DEV_GPU_UTIL)",
     "percent", "{{Hostname}}"),
    ("VRAM belegt", "sum by (Hostname) (DCGM_FI_DEV_FB_USED)"
     " / sum by (Hostname) (DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)",
     "percentunit", "{{Hostname}}"),
    ("GPU-Temperatur", "max by (Hostname) (DCGM_FI_DEV_GPU_TEMP)",
     "celsius", "{{Hostname}}"),
    ("Tokens/s erzeugt",
     "sum by (model_name) (rate(vllm:generation_tokens_total[1m]))",
     "short", "{{model_name}}"),
    ("Prompt-Tokens/s",
     "sum by (model_name) (rate(vllm:prompt_tokens_total[1m]))",
     "short", "{{model_name}}"),
    ("TTFT p95", "histogram_quantile(0.95, sum by (le, model_name)"
     " (rate(vllm:time_to_first_token_seconds_bucket[5m])))",
     "s", "{{model_name}}"),
    ("Warteschlange", "sum by (model_name) (vllm:num_requests_waiting)",
     "short", "{{model_name}}"),
    ("KV-Cache", "max by (model_name) (vllm:kv_cache_usage_perc)",
     "percentunit", "{{model_name}}"),
    ("LiteLLM Requests/s", "sum by (model_group)"
     " (rate(litellm_proxy_total_requests_metric_total[5m]))",
     "reqps", "{{model_group}}"),
    ("LiteLLM Latenz p95", "histogram_quantile(0.95, sum by (le, model)"
     " (rate(litellm_request_total_latency_metric_bucket[5m])))",
     "s", "{{model}}"),
    ("Spend pro Team (24h)",
     "sum by (team_alias) (increase(litellm_spend_metric_total[24h]))",
     "short", "{{team_alias}}"),
    ("Fallbacks nach extern (1h)", "sum by (fallback_model)"
     " (increase(litellm_deployment_successful_fallbacks_total[1h]))",
     "short", "{{fallback_model}}"),
]


def panel(i: int, title: str, expr: str, unit: str, legend: str) -> dict:
    return {
        "id": i + 1,
        "type": "timeseries",
        "title": title,
        "datasource": {"type": "prometheus", "uid": "prometheus"},
        "gridPos": {"h": 8, "w": 12, "x": (i % 2) * 12, "y": (i // 2) * 8},
        "fieldConfig": {"defaults": {"unit": unit}, "overrides": []},
        "targets": [{"refId": "A", "expr": expr, "legendFormat": legend}],
    }


print(json.dumps({
    "title": "KI-Plattform",
    "uid": "ki-plattform",
    "schemaVersion": 39,
    "time": {"from": "now-6h", "to": "now"},
    "refresh": "30s",
    "panels": [panel(i, *p) for i, p in enumerate(PANELS)],
}, indent=1, ensure_ascii=False))
