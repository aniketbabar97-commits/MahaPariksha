"""Pluggable open-source draft model for bulk content generation.

Generation (drafting) is where token volume is highest, so it is the piece worth
moving off paid Claude tokens. Verification stays on Claude (see verify() calls
in generate_questions.py / ca_daily.py) because that is where mistakes are
costly (a wrong answer key or a fabricated quote shipping to users), and a
weaker model there would mean more review work, not less.

Uses any OpenAI-compatible chat-completions endpoint. Groq's free tier is the
default: fast, no cost for moderate volume, and good enough for first-draft
MCQ/flashcard/motivation text that a Claude verification pass will check anyway.

Env:
  DRAFT_PROVIDER  groq (default) | together | openrouter | deepinfra | none
  DRAFT_MODEL     provider-specific model id (sane default per provider below)
  <PROVIDER>_API_KEY   e.g. GROQ_API_KEY, TOGETHER_API_KEY, OPENROUTER_API_KEY, DEEPINFRA_API_KEY

Set DRAFT_PROVIDER=none (or leave every key unset) to fall back to drafting
with Claude too -- generate_questions.py keeps working either way, just at
higher token cost.
"""
import json
import os
import re

_PROVIDERS = {
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "key_env": "GROQ_API_KEY",
        "default_model": "llama-3.3-70b-versatile",
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


def active_provider():
    """Returns the configured provider name, or None if drafting should fall back to Claude."""
    name = os.environ.get("DRAFT_PROVIDER", "groq")
    if name == "none":
        return None
    cfg = _PROVIDERS.get(name)
    if not cfg or not os.environ.get(cfg["key_env"]):
        return None
    return name


def draft_json(prompt: str, *, max_tokens: int = 8000) -> list:
    """Ask the configured open-source model for a JSON array and return it parsed.

    Raises RuntimeError if no open-source provider is configured (caller should
    fall back to Claude in that case) or if the model's output doesn't parse.
    """
    name = active_provider()
    if name is None:
        raise RuntimeError("no open-source draft provider configured (set DRAFT_PROVIDER + its API key)")
    cfg = _PROVIDERS[name]
    import openai  # lazy import: only needed when this path is actually used
    client = openai.OpenAI(base_url=cfg["base_url"], api_key=os.environ[cfg["key_env"]])
    model = os.environ.get("DRAFT_MODEL", cfg["default_model"])
    resp = client.chat.completions.create(
        model=model,
        max_tokens=max_tokens,
        temperature=0.7,
        messages=[
            {"role": "system", "content": "You output ONLY a raw JSON array. No markdown fences, no commentary."},
            {"role": "user", "content": prompt},
        ],
    )
    text = resp.choices[0].message.content.strip()
    text = re.sub(r"^```(json)?|```$", "", text.strip(), flags=re.MULTILINE).strip()
    return json.loads(text)
