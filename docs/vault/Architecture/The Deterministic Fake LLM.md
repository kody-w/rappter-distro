---
title: The Deterministic Fake LLM
status: published
section: Architecture
hook: LLM_FAKE=1. A non-LLM provider is load-bearing for the test suite, not a hack.
---

# The Deterministic Fake LLM

> **Hook.** `LLM_FAKE=1`. A non-LLM provider is load-bearing for the test suite, not a hack.

## What it does

`rapp_brainstem/utils/llm.py` exposes four providers, selected by environment:

```python
def detect_provider() -> str:
    if os.environ.get("LLM_FAKE") == "1":
        return "fake"
    if os.environ.get("AZURE_OPENAI_ENDPOINT") and os.environ.get("AZURE_OPENAI_API_KEY"):
        return "azure-openai"
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    return "fake"
```

The fake provider's logic is 22 lines (`llm.py:191-212`):

```python
def chat_fake(messages, tools=None, tool_choice="auto", model=None) -> dict:
    if tools:
        t = tools[0]
        return {
            "role": "assistant",
            "content": "",
            "tool_calls": [{
                "id": "fake-call-0",
                "type": "function",
                "function": {"name": t["function"]["name"], "arguments": "{}"},
            }],
        }
    last_user = next((m.get("content", "") for m in reversed(messages)
                      if m.get("role") == "user"), "")
    return {"role": "assistant", "content": f"fake-llm: {last_user}"}
```

That's the whole thing. If tools are available, call the first one with empty arguments. Otherwise echo the last user message back with a `fake-llm:` prefix.

## Why this is load-bearing

The fake provider isn't there for cuteness. It is the only way to run the test suite without a real LLM. Three properties depend on it:

**1 — Hermeticity.** Tests that hit a real LLM are flaky by definition (provider downtime, rate limits, model updates) and slow by definition (network round-trip per call). The fake provider makes every brainstem path testable in milliseconds, in CI, with no API key. The test suite (`tests/run-tests.mjs`) runs against `LLM_FAKE=1` for exactly this reason.

**2 — Pipeline coverage.** The fake provider deterministically picks the *first available tool* and calls it with empty arguments. That's not a bug; it's the design. Combined with [[Data Sloshing]], it means a multi-agent pipeline can be driven end-to-end with no LLM judgment — the agents pass deterministic JSON to each other, the fake provider keeps picking tools until there are none left, and the brainstem's tool-call loop terminates on its own (`brainstem.py:957-972`).

This means: **agent pipelines can be tested as integration tests, not just unit tests.** The thing being tested is the pipeline shape, not the LLM's choices.

**3 — Provider-swap proof.** If the fake provider can drive a real pipeline to completion, the pipeline's correctness doesn't depend on which model is configured. That is the proof that the platform's central abstraction (LLM picks; deterministic plumbing carries) is working.

## What it doesn't try to do

The fake provider deliberately does *not* try to mimic LLM judgment. It doesn't:

- Pick the *best* tool for the input. It picks the first.
- Generate plausible response text. It echoes the last user message.
- Vary its output run-to-run. Same input, same output.
- Simulate tool-call selection from prompt context. Tools are picked by position.

These omissions are the design. The fake exists to test plumbing, not behavior. Behavior tests need a real LLM. The line is honest.

## Why it lives next to the real providers

`chat_fake()` lives in `utils/llm.py` alongside `chat_openai()`, `chat_azure_openai()`, and `chat_anthropic()` — not in a `tests/` directory, not behind a flag in a separate test harness. There's a reason.

If the fake were in `tests/`, every test would have to monkey-patch the dispatcher. Monkey-patching couples tests to internals; tests break when internals change. Instead, the dispatcher itself dispatches to the fake when `LLM_FAKE=1` — same code path, same provider abstraction, same return shape. Tests don't patch anything. They set an env var.

This is the same pattern as the storage shim (see [[Local Storage Shim via sys.modules]]): **the test mode is a real provider, selected by environment, not a special hook.** The brainstem doesn't know it's in test mode.

## What it implies for new providers

Every provider added to `utils/llm.py` must be swappable with the fake without changing test code. Concretely:

- Same input shape (`messages`, `tools`, `tool_choice`, `model`).
- Same output shape (assistant message dict with `role`, `content`, optional `tool_calls`).
- Same dispatch entry point (`chat()` at `llm.py:232`).
- No provider-specific side channels (no global state, no thread-local config, no return values that the brainstem doesn't know about).

If a new provider can't satisfy these, the right answer isn't to relax the constraint — it's to wrap the provider in an adapter that does.

## What this rules out

- ❌ Tests that monkey-patch `chat()` directly. The whole point of the fake is to remove the need.
- ❌ A "test-only" code path inside the brainstem that bypasses the LLM dispatch. Tests use the real dispatch with `LLM_FAKE=1`.
- ❌ Provider implementations that emit shapes only their own callers understand. The fake's output shape *is* the contract; new providers conform.
- ❌ Removing the fake "because we have real providers now." The fake is what makes CI work. Real providers don't.

## When to evolve the fake

The fake provider is intentionally minimal, but it can grow if growth doesn't break determinism. Acceptable extensions:

- **Tool selection by name match.** If a test wants to drive a specific tool, the fake could prefer tools whose name matches a regex in the env. Determinism preserved.
- **Multi-call sequences.** A scripted sequence of fake responses for testing multi-round flows. Determinism preserved.

Unacceptable extensions:

- Anything that simulates "judgment" — picking different tools based on prompt content, generating context-aware responses. That defeats determinism.

## Discipline

- Run the test suite with `LLM_FAKE=1` regularly. If a test fails only with a real LLM, the test is testing the LLM, not the platform.
- New tests default to the fake. Real-LLM tests are reserved for behavior verification, not plumbing verification.
- When tempted to mock the LLM, use the fake instead. The fake is the canonical test stub.

## Related

- [[Data Sloshing]]
- [[Local Storage Shim via sys.modules]]
- [[The Auth Cascade]]
- [[The Single-File Agent Bet]]
- [[Vendoring, Not Symlinking]]
