#!/usr/bin/env python3
"""Mini-Eval für den Alias 'code': FIM-Autocomplete und Chat über LiteLLM.

Misst Time-to-first-Token (TTFT) und Gesamtlatenz, prüft einfache Erwartungen.
Umgebung: LITELLM_URL (…/v1), LITELLM_KEY, optional CODE_MODEL, RUNS, FIM_STYLE
FIM_STYLE: qwen (Standard, Qwen2.5-Coder-Tokens) oder plain (Prefix ohne Tokens)
"""
import os
import statistics
import sys
import time

from openai import OpenAI

MODEL = os.getenv("CODE_MODEL", "code")
RUNS = int(os.getenv("RUNS", "5"))
STYLE = os.getenv("FIM_STYLE", "qwen")

FIM_CASES = [  # (Prefix, Suffix, erwartetes Fragment)
    ("def is_even(n: int) -> bool:\n    return ", "\n", "%"),
    ("import json\n\ndef load(path):\n    with open(path) as f:\n        return ",
     "\n", "json"),
    ("apiVersion: v1\nkind: Service\nmetadata:\n  name: web\nspec:\n  ports:\n"
     "    - port: ", "\n", "80"),
]
CHAT_CASES = [  # (Frage, erwartetes Fragment)
    ("Schreibe eine Python-Funktion slugify(s), nur Code.", "def slugify"),
    ("Welcher kubectl-Befehl zeigt die Logs des vorherigen Containers? "
     "Nur der Befehl.", "--previous"),
]


def fim_prompt(prefix: str, suffix: str) -> str:
    if STYLE == "qwen":
        return f"<|fim_prefix|>{prefix}<|fim_suffix|>{suffix}<|fim_middle|>"
    return prefix


def timed_stream(call, **kwargs) -> tuple[float, float, str]:
    t0 = time.perf_counter()  # vor dem Request: Header kommen erst mit Token 1
    ttft, out = None, []
    for chunk in call(**kwargs, stream=True):
        piece = (chunk.choices[0].text if hasattr(chunk.choices[0], "text")
                 else chunk.choices[0].delta.content) if chunk.choices else None
        if piece:
            ttft = ttft or time.perf_counter() - t0
            out.append(piece)
    total = time.perf_counter() - t0
    return (ttft or total) * 1000, total * 1000, "".join(out)


def pct(values: list[float], p: float) -> float:
    values = sorted(values)
    return values[min(len(values) - 1, int(round(p * (len(values) - 1))))]


def main() -> int:
    llm = OpenAI(base_url=os.environ["LITELLM_URL"],
                 api_key=os.environ["LITELLM_KEY"], timeout=60)
    fim_ttft, fim_total, chat_ttft, chat_total, hits, n = [], [], [], [], 0, 0
    for _ in range(RUNS):
        for prefix, suffix, want in FIM_CASES:
            ttft, total, text = timed_stream(
                llm.completions.create, model=MODEL, max_tokens=32,
                prompt=fim_prompt(prefix, suffix), temperature=0,
                stop=["\n\n"])
            fim_ttft.append(ttft)
            fim_total.append(total)
            hits += want in text
            n += 1
            if os.getenv("DEBUG"):
                print(repr(text))
    for question, want in CHAT_CASES:
        ttft, total, text = timed_stream(
            llm.chat.completions.create, model=MODEL, max_tokens=200,
            temperature=0, messages=[{"role": "user", "content": question}])
        chat_ttft.append(ttft)
        chat_total.append(total)
        hits += want in text
        n += 1

    print(f"Modell: {MODEL}  FIM-Stil: {STYLE}  Läufe: {RUNS}")
    print(f"{'Art':<6}{'TTFT p50':>10}{'TTFT p95':>10}{'Total p50':>11}"
          f"{'Total p95':>11}")
    for name, a, b in (("FIM", fim_ttft, fim_total),
                       ("Chat", chat_ttft, chat_total)):
        print(f"{name:<6}{statistics.median(a):>8.0f}ms{pct(a, .95):>8.0f}ms"
              f"{statistics.median(b):>9.0f}ms{pct(b, .95):>9.0f}ms")
    print(f"Treffer: {hits}/{n}")
    p95 = pct(fim_total, .95)
    ok = p95 <= float(os.getenv("FIM_P95_MS", "500"))
    print(("✔" if ok else "✘") + f" FIM p95 {p95:.0f}ms (Ziel ≤ "
          f"{os.getenv('FIM_P95_MS', '500')}ms)")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
