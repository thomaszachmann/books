"""KV-Cache-Rechnung für vLLM (Tag 11)."""
import json
import sys
import urllib.request

repo = sys.argv[1] if len(sys.argv) > 1 else "Qwen/Qwen3-8B-FP8"
url = f"https://huggingface.co/{repo}/resolve/main/config.json"
cfg = json.load(urllib.request.urlopen(url))
layers, kv_heads = cfg["num_hidden_layers"], cfg["num_key_value_heads"]
head_dim = cfg.get("head_dim") or cfg["hidden_size"] // cfg["num_attention_heads"]
kv_bytes = 2  # BF16-KV-Cache; mit --kv-cache-dtype fp8 halbiert
per_token = 2 * layers * kv_heads * head_dim * kv_bytes  # K und V
weights_gb = float(sys.argv[2]) if len(sys.argv) > 2 else 9.4  # Drill 1
gpu_gb, util, overhead_gb = 24, 0.80, 1.5
kv_gb = gpu_gb * util - weights_gb - overhead_gb
tokens = int(kv_gb * 1024**3 / per_token)
print(f"{repo}: {per_token / 1024:.0f} KiB KV pro Token")
print(f"KV-Budget {kv_gb:.1f} GB -> ca. {tokens:,} Tokens im Cache")
for ctx in (4096, 16384, 32768):
    print(f"  max-model-len {ctx:>6}: ca. {tokens // ctx} volle Sequenzen parallel")
