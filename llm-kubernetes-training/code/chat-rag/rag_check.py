#!/usr/bin/env python3
"""RAG von Hand: Dokumente einbetten (LiteLLM 'embed'), in Qdrant speichern,
Testfragen stellen (LiteLLM 'chat-small') und Treffer prüfen.

Umgebung:
  LITELLM_URL     z. B. http://127.0.0.1:4000/v1
  LITELLM_KEY     Virtual Key (Lab: sk-lab-...)
  QDRANT_URL      z. B. http://127.0.0.1:6333 oder ":memory:" für lokalen Test
  QDRANT_API_KEY  optional
"""
import os
import pathlib
import sys
import time
import uuid

from openai import OpenAI
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

COLLECTION = "rag-check"
DOCS = pathlib.Path(__file__).parent / "docs"
EMBED = os.getenv("EMBED_MODEL", "embed")
CHAT = os.getenv("CHAT_MODEL", "chat-small")

# Frage, erwartete Quelle (None = egal), Schlüsselwort in der Antwort
QUESTIONS = [
    ("Wie hoch ist die Pauschale pro Bereitschaftswoche?",
     "bereitschaft.md", "350"),
    ("Wie schnell muss ich in der Bereitschaft bei P1 reagieren?",
     "bereitschaft.md", "15"),
    ("Wie hoch ist das LLM-Standardbudget eines Teams?",
     "gpu-richtlinie.md", "50"),
    ("Wie oft werden VPN-Schlüssel rotiert?", "vpn.md", "90"),
]


def chunks(text: str) -> list[str]:
    """Absatzweise schneiden – Open WebUI nutzt CHUNK_SIZE/CHUNK_OVERLAP."""
    return [p.strip() for p in text.split("\n\n") if p.strip()]


def main() -> int:
    llm = OpenAI(base_url=os.environ["LITELLM_URL"],
                 api_key=os.environ["LITELLM_KEY"])
    url = os.environ.get("QDRANT_URL", ":memory:")
    if url == ":memory:":
        qdrant = QdrantClient(location=":memory:")
    else:
        qdrant = QdrantClient(url=url, api_key=os.getenv("QDRANT_API_KEY"))

    texts, sources = [], []
    for f in sorted(DOCS.glob("*.md")):
        for c in chunks(f.read_text(encoding="utf-8")):
            texts.append(c)
            sources.append(f.name)
    t0 = time.perf_counter()
    vecs = [d.embedding for d in llm.embeddings.create(model=EMBED,
                                                       input=texts).data]
    print(f"{len(texts)} Chunks eingebettet, dim={len(vecs[0])}, "
          f"{time.perf_counter() - t0:.2f}s")

    if qdrant.collection_exists(COLLECTION):
        qdrant.delete_collection(COLLECTION)
    qdrant.create_collection(COLLECTION, vectors_config=VectorParams(
        size=len(vecs[0]), distance=Distance.COSINE))
    qdrant.upsert(COLLECTION, points=[
        PointStruct(id=str(uuid.uuid4()), vector=v,
                    payload={"text": t, "source": s})
        for v, t, s in zip(vecs, texts, sources)])

    ok = 0
    for question, want_src, keyword in QUESTIONS:
        qv = llm.embeddings.create(model=EMBED, input=[question]).data[0]
        hits = qdrant.query_points(COLLECTION, query=qv.embedding,
                                   limit=3).points
        context = "\n---\n".join(h.payload["text"] for h in hits)
        t0 = time.perf_counter()
        answer = llm.chat.completions.create(
            model=CHAT, temperature=0, max_tokens=400,  # Qwen3 denkt mit
            messages=[
                {"role": "system", "content":
                 "Antworte kurz auf Deutsch, nur mit Fakten aus dem Kontext. "
                 "Steht es nicht im Kontext, sage 'weiß ich nicht'."},
                {"role": "user",
                 "content": f"Kontext:\n{context}\n\nFrage: {question}"},
            ]).choices[0].message.content.strip()
        dt = time.perf_counter() - t0
        src_ok = want_src is None or hits[0].payload["source"] == want_src
        ans_ok = keyword.lower() in answer.lower()
        ok += src_ok and ans_ok
        mark = "✔" if src_ok and ans_ok else "✘"
        print(f"{mark} [{hits[0].score:.2f} {hits[0].payload['source']}] "
              f"{question}\n    -> {answer[:100]} ({dt:.1f}s)")
    print(f"{ok}/{len(QUESTIONS)} Fragen korrekt beantwortet")
    return 0 if ok == len(QUESTIONS) else 1


if __name__ == "__main__":
    sys.exit(main())
