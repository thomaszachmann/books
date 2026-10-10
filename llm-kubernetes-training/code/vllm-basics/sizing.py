#!/usr/bin/env python3
"""Grobe vLLM-Sizing-Rechnung: Gewichte + KV-Cache pro Token und pro GPU.

Aufruf: python3 sizing.py <hf-repo> <params_mrd> <gpu_gib> [max_len] [kv_bytes]
Beispiel: python3 sizing.py Qwen/Qwen3-8B 8.2 24 8192 2
"""
import json
import sys
import urllib.request

GIB = 1024**3


def load_config(repo: str) -> dict:
    url = f"https://huggingface.co/{repo}/resolve/main/config.json"
    with urllib.request.urlopen(url, timeout=20) as resp:
        cfg = json.load(resp)
    return cfg.get("text_config", cfg)  # multimodale Modelle verschachteln


def main() -> None:
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    repo, params = sys.argv[1], float(sys.argv[2])
    gpu_gib = float(sys.argv[3])
    max_len = int(sys.argv[4]) if len(sys.argv) > 4 else 8192
    kv_bytes = int(sys.argv[5]) if len(sys.argv) > 5 else 2  # bf16=2, fp8=1
    util = 0.92  # vLLM-Default --gpu-memory-utilization

    c = load_config(repo)
    layers = c["num_hidden_layers"]
    kv_heads = c.get("num_key_value_heads", c["num_attention_heads"])
    head_dim = c.get("head_dim") or c["hidden_size"] // c["num_attention_heads"]

    weights = params * 1e9 * 2 / GIB  # bf16-Gewichte
    per_token = 2 * layers * kv_heads * head_dim * kv_bytes  # K und V
    budget = gpu_gib * util - weights - 1.5  # ~1,5 GiB Aktivierungen/Graphen
    tokens = int(budget * GIB / per_token) if budget > 0 else 0

    print(f"Modell           {repo}")
    print(f"Layer/KV-Heads   {layers}/{kv_heads}, head_dim {head_dim}")
    print(f"Gewichte (bf16)  {weights:5.1f} GiB")
    print(f"KV pro Token     {per_token / 1024:5.1f} KiB")
    print(f"KV-Budget        {max(budget, 0):5.1f} GiB = {tokens} Tokens")
    print(f"Volle Sequenzen  {tokens // max_len} à {max_len} Tokens")


if __name__ == "__main__":
    main()
