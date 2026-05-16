#!/usr/bin/env python3
"""
swarm/llm.py — stdlib-only LLM dispatch for the swarm server.

Provider precedence (first one with credentials wins):
    1. Azure OpenAI (AZURE_OPENAI_ENDPOINT + AZURE_OPENAI_API_KEY [+ AZURE_OPENAI_DEPLOYMENT])
    2. OpenAI       (OPENAI_API_KEY)
    3. Anthropic    (ANTHROPIC_API_KEY)
    4. Fake mode    (LLM_FAKE=1) — deterministic stub for tests

Uses urllib only — no openai / anthropic SDK dependency, so this works
under the stdlib-only swarm server AND under Azure Functions without
extra installs.

The wire format we accept and emit is OpenAI-compatible:
    chat({"messages":[…], "tools":[…], "model":…}) →
    {"role":"assistant", "content":…, "tool_calls":[…]}
"""

from __future__ import annotations
import json
import os
import urllib.error
import urllib.request


# ─── Provider detection ─────────────────────────────────────────────────

def detect_provider() -> str:
    """Returns one of: 'azure-openai', 'openai', 'anthropic', 'fake'."""
    if os.environ.get("LLM_FAKE") == "1":
        return "fake"
    if os.environ.get("AZURE_OPENAI_ENDPOINT") and os.environ.get("AZURE_OPENAI_API_KEY"):
        return "azure-openai"
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    return "fake"


def provider_status() -> dict:
    """Diagnostic — what creds are present, what provider would be used."""
    return {
        "provider": detect_provider(),
        "azure_openai_configured": bool(
            os.environ.get("AZURE_OPENAI_ENDPOINT") and os.environ.get("AZURE_OPENAI_API_KEY")
        ),
        "openai_configured": bool(os.environ.get("OPENAI_API_KEY")),
        "anthropic_configured": bool(os.environ.get("ANTHROPIC_API_KEY")),
        "azure_endpoint": os.environ.get("AZURE_OPENAI_ENDPOINT", ""),
        "azure_deployment": os.environ.get("AZURE_OPENAI_DEPLOYMENT", ""),
        "fake_mode": os.environ.get("LLM_FAKE") == "1",
    }


# ─── Common HTTP helper ─────────────────────────────────────────────────

def _http_post(url: str, headers: dict, body: dict, timeout: int = 60) -> dict:
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        try:
            err_body = e.read().decode("utf-8")
        except Exception:
            err_body = str(e)
        raise RuntimeError(f"LLM HTTP {e.code}: {err_body[:400]}")
    except urllib.error.URLError as e:
        raise RuntimeError(f"LLM network error: {e}")


# ─── Azure OpenAI ───────────────────────────────────────────────────────

def chat_azure_openai(messages: list, tools: list | None = None,
                      tool_choice: str = "auto", model: str | None = None) -> dict:
    """OpenAI-format chat completion against an Azure OpenAI deployment."""
    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"].rstrip("/")
    key = os.environ["AZURE_OPENAI_API_KEY"]
    deployment = model or os.environ.get("AZURE_OPENAI_DEPLOYMENT") \
                 or os.environ.get("AZURE_OPENAI_DEPLOYMENT_NAME", "")
    api_version = os.environ.get("AZURE_OPENAI_API_VERSION", "2025-01-01-preview")

    # Endpoint variants we accept:
    #   1. Full v1 URL:    https://…/openai/v1/chat/completions
    #      → use as-is, NO api-version query (v1 doesn't accept it)
    #   2. Full legacy URL: https://…/openai/deployments/<d>/chat/completions
    #      → append ?api-version=…
    #   3. Bare resource:  https://…
    #      → build the legacy deployment URL ourselves
    is_v1 = "/openai/v1/" in endpoint
    if "/chat/completions" in endpoint:
        url = endpoint
        if not is_v1 and "?" not in url:
            url += f"?api-version={api_version}"
    else:
        url = f"{endpoint}/openai/deployments/{deployment}/chat/completions?api-version={api_version}"

    body = {"messages": messages}
    if tools:
        body["tools"] = tools
        body["tool_choice"] = tool_choice
    # v1 + legacy chat-completions both want a model in the body
    if "/chat/completions" in endpoint:
        body["model"] = model or deployment

    resp = _http_post(url, {
        "Content-Type": "application/json",
        "api-key": key,
    }, body)
    return _normalize_openai_response(resp)


# ─── OpenAI ─────────────────────────────────────────────────────────────

def chat_openai(messages: list, tools: list | None = None,
                tool_choice: str = "auto", model: str | None = None) -> dict:
    body = {
        "model": model or os.environ.get("OPENAI_MODEL", "gpt-4o"),
        "messages": messages,
    }
    if tools:
        body["tools"] = tools
        body["tool_choice"] = tool_choice
    resp = _http_post("https://api.openai.com/v1/chat/completions", {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {os.environ['OPENAI_API_KEY']}",
    }, body)
    return _normalize_openai_response(resp)


# ─── Anthropic ──────────────────────────────────────────────────────────

def chat_anthropic(messages: list, tools: list | None = None,
                   tool_choice: str = "auto", model: str | None = None) -> dict:
    """Anthropic Messages API. Translates OpenAI-style tools → Anthropic tools."""
    # Pull system prompt out of messages array (Anthropic puts it at top level)
    sys_prompt = ""
    msgs_clean = []
    for m in messages:
        if m.get("role") == "system":
            sys_prompt = (sys_prompt + "\n" + (m.get("content") or "")).strip()
        else:
            msgs_clean.append(m)

    body = {
        "model": model or os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
        "max_tokens": 4096,
        "messages": msgs_clean,
    }
    if sys_prompt:
        body["system"] = sys_prompt
    if tools:
        body["tools"] = [{
            "name": t["function"]["name"],
            "description": t["function"].get("description", ""),
            "input_schema": t["function"].get("parameters", {"type": "object", "properties": {}}),
        } for t in tools if t.get("type") == "function"]

    resp = _http_post("https://api.anthropic.com/v1/messages", {
        "Content-Type": "application/json",
        "x-api-key": os.environ["ANTHROPIC_API_KEY"],
        "anthropic-version": "2023-06-01",
    }, body)

    # Translate Anthropic response → OpenAI shape
    out_text = ""
    tool_calls = []
    for blk in resp.get("content", []):
        if blk.get("type") == "text":
            out_text += blk.get("text", "")
        elif blk.get("type") == "tool_use":
            tool_calls.append({
                "id": blk.get("id", ""),
                "type": "function",
                "function": {
                    "name": blk.get("name", ""),
                    "arguments": json.dumps(blk.get("input", {})),
                },
            })
    msg = {"role": "assistant", "content": out_text}
    if tool_calls:
        msg["tool_calls"] = tool_calls
    return msg


# ─── Fake (for tests) ───────────────────────────────────────────────────

def chat_fake(messages: list, tools: list | None = None,
              tool_choice: str = "auto", model: str | None = None) -> dict:
    """Deterministic stub. If a tool is available, calls the FIRST tool with
    empty args (one round) — otherwise echoes back the last user message
    with a 'fake-llm:' prefix."""
    if tools:
        t = tools[0]
        return {
            "role": "assistant",
            "content": "",
            "tool_calls": [{
                "id": "fake-call-0",
                "type": "function",
                "function": {
                    "name": t["function"]["name"],
                    "arguments": "{}",
                },
            }],
        }
    last_user = next((m.get("content", "") for m in reversed(messages)
                      if m.get("role") == "user"), "")
    return {"role": "assistant", "content": f"fake-llm: {last_user}"}


# ─── Normalize ──────────────────────────────────────────────────────────

def _normalize_openai_response(resp: dict) -> dict:
    """Pull the message off a chat-completions response. Returns the assistant
    message dict (role + content + optional tool_calls)."""
    choices = resp.get("choices") or []
    if not choices:
        return {"role": "assistant", "content": resp.get("error", {}).get("message", "")}
    msg = choices[0].get("message", {}) or {}
    out = {"role": "assistant", "content": msg.get("content") or ""}
    if msg.get("tool_calls"):
        out["tool_calls"] = msg["tool_calls"]
    return out


# ─── Top-level dispatch ─────────────────────────────────────────────────

def chat(messages: list, tools: list | None = None,
         tool_choice: str = "auto", model: str | None = None) -> dict:
    """Dispatch to the configured provider. Returns an OpenAI-shape
    assistant message dict."""
    p = detect_provider()
    if p == "azure-openai":
        return chat_azure_openai(messages, tools, tool_choice, model)
    if p == "openai":
        return chat_openai(messages, tools, tool_choice, model)
    if p == "anthropic":
        return chat_anthropic(messages, tools, tool_choice, model)
    return chat_fake(messages, tools, tool_choice, model)


if __name__ == "__main__":
    print(json.dumps(provider_status(), indent=2))
