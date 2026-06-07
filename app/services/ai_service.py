"""
AI Service v2 — Multi-provider, streaming support, config persistence.

Providers:
    - Ollama (local, free)
    - OpenAI (cloud)
    - Anthropic (cloud)

Config persisted in UserSettings via Ryx.
"""

from __future__ import annotations

import json
import hashlib
import asyncio
from typing import AsyncIterator
from dataclasses import dataclass, field

import httpx

from app.core.settings import PATHS


@dataclass
class AIProviderConfig:
    provider: str = "ollama"
    model: str = "codellama:7b"
    endpoint: str = "http://localhost:11434"
    api_key: str = ""
    max_tokens: int = 1024
    temperature: float = 0.2

    @classmethod
    def from_dict(cls, data: dict) -> AIProviderConfig:
        return cls(
            provider=data.get("provider", "ollama"),
            model=data.get("model", "codellama:7b"),
            endpoint=data.get("endpoint", "http://localhost:11434"),
            api_key=data.get("api_key", ""),
            max_tokens=data.get("max_tokens", 1024),
            temperature=data.get("temperature", 0.2),
        )


@dataclass
class ChatMessage:
    role: str  # "system", "user", "assistant"
    content: str

    def to_dict(self) -> dict:
        return {"role": self.role, "content": self.content}


# ── Prompt templates ─────────────────────────────────────

SYSTEM_PROMPT = (
    "You are Ember AI, an expert coding assistant integrated into the Ember code editor. "
    "You help developers write, understand, and refactor code. "
    "Keep responses concise and focused on code. "
    "Use markdown code blocks with language identifiers when showing code."
)

EXPLAIN_PROMPT = """Explain the following code clearly and concisely.
Focus on:
1. What it does (high-level purpose)
2. Key patterns or algorithms used
3. Any potential issues or improvements

Code to explain (language: {language}):
```
{code}
```"""

REFACTOR_PROMPT = """Refactor the following code to improve its quality.
Apply these principles:
- Improve readability and maintainability
- Follow best practices for {language}
- Keep the same behavior and interface
- Add type hints where applicable
- Extract complex logic into smaller functions

Return ONLY the refactored code in a code block.

Original code:
```
{code}
```"""

GENERATE_TESTS_PROMPT = """Generate comprehensive unit tests for the following code.
Use pytest style with fixtures where appropriate.
Cover edge cases and error conditions.

Code to test (language: {language}):
```
{code}
```

Return ONLY the test code in a code block."""

INLINE_COMPLETION_PROMPT = (
    "Complete the code at the cursor position. "
    "Return ONLY the exact characters to insert — no explanation, no markdown. "
    "The completion should be the most likely continuation of the code.\n\n"
    "{context}"
)


# ── AIService ─────────────────────────────────────────────

class AIService:
    def __init__(self):
        self._config = AIProviderConfig()
        self._client: httpx.AsyncClient | None = None

    # ── Config ────────────────────────────────────────────

    @property
    def config(self) -> AIProviderConfig:
        return self._config

    def configure(self, **kwargs) -> None:
        for k, v in kwargs.items():
            if hasattr(self._config, k):
                setattr(self._config, k, v)

    async def load_config(self) -> AIProviderConfig:
        from app.data.models import UserSettings

        try:
            s = await UserSettings.objects.get(key="ai_config")
            self._config = AIProviderConfig.from_dict(s.value or {})
        except Exception:
            pass
        return self._config

    async def save_config(self) -> None:
        from app.data.models import UserSettings

        data = {
            "provider": self._config.provider,
            "model": self._config.model,
            "endpoint": self._config.endpoint,
            "api_key": self._config.api_key,
            "max_tokens": self._config.max_tokens,
            "temperature": self._config.temperature,
        }
        obj, created = await UserSettings.objects.get_or_create(
            key="ai_config",
            defaults={"value": data},
        )
        if not created:
            obj.value = data
            await obj.save()

    # ── Client ────────────────────────────────────────────

    async def _get_client(self) -> httpx.AsyncClient:
        if self._client is None:
            self._client = httpx.AsyncClient(timeout=60.0)
        return self._client

    # ── Chat ──────────────────────────────────────────────

    async def chat(
        self,
        messages: list[ChatMessage],
        context: str = "",
    ) -> str:
        full_messages = [ChatMessage(role="system", content=SYSTEM_PROMPT)]
        if context:
            full_messages.append(ChatMessage(
                role="system",
                content=f"Current file context:\n```\n{context[:4000]}\n```",
            ))
        full_messages.extend(messages)

        if self._config.provider == "ollama":
            return await self._ollama_chat(full_messages)
        elif self._config.provider == "openai":
            return await self._openai_chat(full_messages)
        else:
            return f"Provider '{self._config.provider}' not supported."

    async def chat_stream(
        self,
        messages: list[ChatMessage],
        context: str = "",
    ) -> AsyncIterator[str]:
        full_messages = [ChatMessage(role="system", content=SYSTEM_PROMPT)]
        if context:
            full_messages.append(ChatMessage(
                role="system",
                content=f"Current file context:\n```\n{context[:4000]}\n```",
            ))
        full_messages.extend(messages)

        if self._config.provider == "ollama":
            async for chunk in self._ollama_chat_stream(full_messages):
                yield chunk
        else:
            result = await self.chat(messages, context)
            yield result

    # ── Actions ───────────────────────────────────────────

    async def explain_code(self, code: str, language: str = "python") -> str:
        prompt = EXPLAIN_PROMPT.format(code=code[:8000], language=language)
        msg = [ChatMessage(role="user", content=prompt)]
        return await self.chat(msg)

    async def refactor_code(self, code: str, language: str = "python") -> str:
        prompt = REFACTOR_PROMPT.format(code=code[:8000], language=language)
        msg = [ChatMessage(role="user", content=prompt)]
        return await self.chat(msg)

    async def generate_tests(self, code: str, language: str = "python") -> str:
        prompt = GENERATE_TESTS_PROMPT.format(code=code[:8000], language=language)
        msg = [ChatMessage(role="user", content=prompt)]
        return await self.chat(msg)

    # ── Inline completion ─────────────────────────────────

    async def get_inline_suggestion(self, code: str, cursor_offset: int) -> str | None:
        cache_key = hashlib.sha256(
            f"{code}:{cursor_offset}:{self._config.model}".encode()
        ).hexdigest()

        cached = await self._get_cache(cache_key)
        if cached:
            return cached

        context = code[:cursor_offset]
        prompt = INLINE_COMPLETION_PROMPT.format(context=context)

        try:
            if self._config.provider == "ollama":
                result = await self._ollama_complete(prompt, max_tokens=128, temperature=0.1)
            elif self._config.provider == "openai":
                result = await self._openai_complete(prompt, max_tokens=128, temperature=0.1)
            else:
                return None

            first_line = result.strip().split("\n")[0][:200]
            if first_line:
                await self._set_cache(cache_key, first_line)
            return first_line or None
        except Exception as e:
            print(f"[AIService] Inline error: {e}")
            return None

    # ── Provider implementations ──────────────────────────

    async def _ollama_chat(self, messages: list[ChatMessage]) -> str:
        client = await self._get_client()
        resp = await client.post(
            f"{self._config.endpoint}/api/chat",
            json={
                "model": self._config.model,
                "messages": [m.to_dict() for m in messages],
                "stream": False,
                "options": {
                    "num_predict": self._config.max_tokens,
                    "temperature": self._config.temperature,
                },
            },
        )
        data = resp.json()
        return data.get("message", {}).get("content", "")

    async def _ollama_chat_stream(
        self, messages: list[ChatMessage]
    ) -> AsyncIterator[str]:
        client = await self._get_client()
        async with client.stream(
            "POST",
            f"{self._config.endpoint}/api/chat",
            json={
                "model": self._config.model,
                "messages": [m.to_dict() for m in messages],
                "stream": True,
                "options": {
                    "num_predict": self._config.max_tokens,
                    "temperature": self._config.temperature,
                },
            },
        ) as resp:
            async for line in resp.aiter_lines():
                if not line.strip():
                    continue
                try:
                    data = json.loads(line)
                    content = data.get("message", {}).get("content", "")
                    if content:
                        yield content
                except json.JSONDecodeError:
                    pass

    async def _ollama_complete(
        self, prompt: str, max_tokens: int = 128, temperature: float = 0.2
    ) -> str:
        client = await self._get_client()
        resp = await client.post(
            f"{self._config.endpoint}/api/generate",
            json={
                "model": self._config.model,
                "prompt": prompt,
                "stream": False,
                "system": SYSTEM_PROMPT,
                "options": {
                    "num_predict": max_tokens,
                    "temperature": temperature,
                },
            },
        )
        data = resp.json()
        return data.get("response", "")

    async def _openai_chat(self, messages: list[ChatMessage]) -> str:
        client = await self._get_client()
        resp = await client.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {self._config.api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self._config.model,
                "messages": [m.to_dict() for m in messages],
                "max_tokens": self._config.max_tokens,
                "temperature": self._config.temperature,
            },
        )
        data = resp.json()
        return data.get("choices", [{}])[0].get("message", {}).get("content", "")

    async def _openai_complete(
        self, prompt: str, max_tokens: int = 128, temperature: float = 0.2
    ) -> str:
        client = await self._get_client()
        resp = await client.post(
            "https://api.openai.com/v1/completions",
            headers={
                "Authorization": f"Bearer {self._config.api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": self._config.model.replace("gpt-", "code-"),
                "prompt": prompt,
                "max_tokens": max_tokens,
                "temperature": temperature,
            },
        )
        data = resp.json()
        return data.get("choices", [{}])[0].get("text", "")

    # ── Cache ─────────────────────────────────────────────

    async def _get_cache(self, cache_key: str) -> str | None:
        from app.data.models import AICache

        try:
            entry = await AICache.objects.get(prompt_hash=cache_key)
            entry.hit_count += 1
            await entry.save(update_fields=["hit_count"])
            return entry.response
        except Exception:
            return None

    async def _set_cache(self, cache_key: str, response: str) -> None:
        from app.data.models import AICache

        try:
            await AICache.objects.create(
                prompt_hash=cache_key,
                response=response,
                provider=self._config.provider,
                model=self._config.model,
            )
        except Exception:
            pass
