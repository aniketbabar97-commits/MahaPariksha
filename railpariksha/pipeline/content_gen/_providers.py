"""Shared LLM-calling glue for the content_gen scripts. Two providers (Groq, free
tier via api.groq.com; Gemini, free tier via generativelanguage.googleapis.com),
each queried through plain urllib so no extra dependency is needed beyond stdlib.

Both providers meter usage PER MODEL, not per account — if one model's daily
quota is exhausted, switching MODEL to a different model id on the same
provider/key gets a fresh quota immediately, without waiting ~24h for reset.
See README.md in this directory for the current recommended models and how to
rotate when a script starts hitting persistent 429s.
"""
import json
import os
import re
import time
import urllib.request
import urllib.error


def _json_in(text):
    """Parse the first JSON object in free text (for calls made without JSON mode)."""
    start, end = text.find("{"), text.rfind("}")
    return json.loads(text[start:end + 1])


def groq_ask(model, prompt, retries=5, temperature=0.7, json_mode=True):
    """json_mode=False skips Groq's response_format, which rejects reasoning models'
    long outputs with a 400 json_validate_failed; the reply is parsed with _json_in."""
    api_key = os.environ["GROQ_API_KEY"]
    url = "https://api.groq.com/openai/v1/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": temperature,
    }
    if json_mode:
        payload["response_format"] = {"type": "json_object"}
    body = json.dumps(payload).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={
                "Authorization": f"Bearer {api_key}", "Content-Type": "application/json",
                # Groq blocks Python's default urllib User-Agent with a 403; a
                # normal browser/curl-looking one works fine.
                "User-Agent": "curl/8.5.0"}, method="POST")
            with urllib.request.urlopen(req, timeout=180) as r:
                data = json.loads(r.read())
            content = data["choices"][0]["message"]["content"]
            return json.loads(content) if json_mode else _json_in(content)
        except urllib.error.HTTPError as e:
            if e.code in (429, 403, 500, 503) and attempt < retries - 1:
                body_err = e.read().decode(errors="ignore")
                wait = 6 * (attempt + 1)
                m = re.search(r"try again in ([\d.]+)s", body_err)
                if m:
                    wait = float(m.group(1)) + 1
                time.sleep(wait)
                continue
            raise
        except (json.JSONDecodeError, KeyError, ValueError) as e:
            if attempt < retries - 1:
                time.sleep(4)
                continue
            raise


def gemini_ask(model, prompt, retries=5, temperature=0.7, api_key_env="GEMINI_API_KEY"):
    api_key = os.environ[api_key_env]
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": temperature, "responseMimeType": "application/json"},
    }).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={
                "Content-Type": "application/json", "User-Agent": "curl/8.5.0"}, method="POST")
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.loads(r.read())
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            return json.loads(text)
        except urllib.error.HTTPError as e:
            if e.code in (429, 403, 500, 503) and attempt < retries - 1:
                body_err = e.read().decode(errors="ignore")
                wait = 8 * (attempt + 1)
                m = re.search(r'"retryDelay":\s*"([\d.]+)s"', body_err)
                if m:
                    wait = float(m.group(1)) + 1
                time.sleep(wait)
                continue
            raise
        except (json.JSONDecodeError, KeyError, IndexError):
            if attempt < retries - 1:
                time.sleep(4)
                continue
            raise


def ask(provider, model, prompt, **kw):
    if provider == "groq":
        return groq_ask(model, prompt, **kw)
    if provider == "gemini":
        return gemini_ask(model, prompt, **kw)
    raise ValueError(f"unknown provider {provider!r}")


def norm(s):
    """Normalize a question string for duplicate detection."""
    return re.sub(r"[^a-z0-9]+", "", s.lower())
