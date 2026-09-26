"""Pluggable open-source models for bulk content generation and cross-checking.

Generation (drafting) is where token volume is highest, so it's the piece worth
moving off paid tokens entirely. The default flow in generate_questions.py uses
NO Claude at all: one open-source model drafts, a second, independently-trained
open-source model blind-solves each item without seeing the claimed answer, and
only items both agree on ship. Disagreements are parked for a later audit
(content/pending_review/) rather than shipped or silently dropped -- see
generate_questions.py for why agreement alone isn't full proof of correctness.

Env:
  DRAFT_PROVIDER   which provider drafts. Default: groq
  CHECK_PROVIDER   which provider cross-checks. Default: gemini
  DRAFT_MODEL / CHECK_MODEL   override the provider's default model id
  <PROVIDER>_API_KEY   GROQ_API_KEY, GEMINI_API_KEY, TOGETHER_API_KEY, OPENROUTER_API_KEY, DEEPINFRA_API_KEY

Pick DRAFT_PROVIDER and CHECK_PROVIDER from *different* providers/model families
on purpose -- two models from the same lineage are more likely to share the same
blind spot (both confidently wrong on the same fact), which defeats the point of
cross-checking. Groq (Llama/Qwen/GPT-OSS family) + Gemini (Google's own family)
are a genuinely independent pair.
"""
import json
import os
import re

_PROVIDERS = {
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "key_env": "GROQ_API_KEY",
        "default_model": "openai/gpt-oss-120b",
    },
    "gemini": {
        "base_url": "https://generativelanguage.googleapis.com/v1beta/openai/",
        "key_env": "GEMINI_API_KEY",
        "default_model": "gemini-2.5-flash",
    },
    "together": {
        "base_url": "https://api.together.xyz/v1",
        "key_env": "TOGETHER_API_KEY",
        "default_model": "Qwen/Qwen2.5-72B-Instruct-Turbo",
    },
    "openrouter": {
        "base_url": "https://openrouter.ai/api/v1",
        "key_env": "OPENROUTER_API_KEY",
        "default_model": "qwen/qwen-2.5-72b-instruct",
    },
    "deepinfra": {
        "base_url": "https://api.deepinfra.com/v1/openai",
        "key_env": "DEEPINFRA_API_KEY",
        "default_model": "Qwen/Qwen2.5-72B-Instruct",
    },
}


def is_configured(provider: str) -> bool:
    cfg = _PROVIDERS.get(provider)
    return bool(cfg and os.environ.get(cfg["key_env"]))


def active_provider():
    """Back-compat: the single provider DRAFT_PROVIDER names, or None if unconfigured."""
    name = os.environ.get("DRAFT_PROVIDER", "groq")
    if name == "none" or not is_configured(name):
        return None
    return name


def _client(provider: str):
    cfg = _PROVIDERS[provider]
    import openai  # lazy import: only needed when this path is actually used
    return openai.OpenAI(base_url=cfg["base_url"], api_key=os.environ[cfg["key_env"]])


def call_json(provider: str, prompt: str, *, model_env: str = None, max_tokens: int = 8000):
    """Ask the named provider for JSON (an array or object, per the prompt) and return it parsed.

    Raises RuntimeError if that provider has no API key configured.
    """
    if not is_configured(provider):
        cfg = _PROVIDERS.get(provider)
        key_env = cfg["key_env"] if cfg else "?"
        raise RuntimeError(f"provider '{provider}' not configured (set {key_env})")
    cfg = _PROVIDERS[provider]
    client = _client(provider)
    model = os.environ.get(model_env, cfg["default_model"]) if model_env else cfg["default_model"]
    resp = client.chat.completions.create(
        model=model,
        max_tokens=max_tokens,
        temperature=0.7,
        messages=[
            {"role": "system", "content": "You output ONLY raw JSON. No markdown fences, no commentary."},
            {"role": "user", "content": prompt},
        ],
    )
    text = resp.choices[0].message.content.strip()
    text = re.sub(r"^```(json)?|```$", "", text.strip(), flags=re.MULTILINE).strip()
    return json.loads(text)


def draft_json(prompt: str, *, max_tokens: int = 8000) -> list:
    """Back-compat wrapper: draft via whichever provider DRAFT_PROVIDER names."""
    name = active_provider()
    if name is None:
        raise RuntimeError("no open-source draft provider configured (set DRAFT_PROVIDER + its API key)")
    return call_json(name, prompt, model_env="DRAFT_MODEL", max_tokens=max_tokens)
