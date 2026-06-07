"""
ChatViewModel — Manages chat history, context, and AI interactions.

Connected to the ChatView QML panel via Property<> bindings.
"""

from __future__ import annotations

from PySide6.QtCore import QObject, Signal, Slot, Property
from app.core.async_tasks import schedule
from app.core.events import EventBus


class ChatMessageModel:
    def __init__(self, role: str, content: str):
        self.role = role
        self.content = content

    def to_dict(self) -> dict:
        return {"role": self.role, "content": self.content}


class ChatViewModel(QObject):
    messagesChanged = Signal()
    responseStreaming = Signal(str)
    responseFinished = Signal(str)
    contextChanged = Signal(str)

    def __init__(self, events: EventBus, parent: QObject | None = None):
        super().__init__(parent)
        self._events = events
        self._messages: list[ChatMessageModel] = []
        self._context = ""
        self._is_streaming = False

    # ── Messages ──────────────────────────────────────────

    @Slot(str)
    def sendMessage(self, text: str) -> None:
        if not text.strip():
            return
        self._messages.append(ChatMessageModel(role="user", content=text))
        self.messagesChanged.emit()
        schedule(self._process_message(text))

    async def _process_message(self, text: str) -> None:
        from app.services.ai_service import AIService, ChatMessage

        self._is_streaming = True

        ai = AIService()
        await ai.load_config()

        history = [ChatMessage(role=m.role, content=m.content) for m in self._messages[:-1]]
        history.append(ChatMessage(role="user", content=text))

        full_response = ""
        try:
            async for chunk in ai.chat_stream(history, context=self._context):
                full_response += chunk
                self.responseStreaming.emit(chunk)
        except Exception as e:
            full_response = f"Error: {e}"

        self._messages.append(ChatMessageModel(role="assistant", content=full_response))
        self._is_streaming = False
        self.messagesChanged.emit()
        self.responseFinished.emit(full_response)

    @Slot()
    def clearMessages(self) -> None:
        self._messages.clear()
        self.messagesChanged.emit()

    @Slot(str)
    def setContext(self, code: str) -> None:
        self._context = code
        self.contextChanged.emit(code)

    @Property("QVariantList", notify=messagesChanged)
    def messages(self) -> list[dict]:
        return [m.to_dict() for m in self._messages]

    @Property(bool, notify=messagesChanged)
    def isStreaming(self) -> bool:
        return self._is_streaming

    @Property(str, notify=contextChanged)
    def contextPreview(self) -> str:
        if not self._context:
            return ""
        lines = self._context.strip().split("\n")[:3]
        return "\n".join(lines)

    # ── AI Actions ────────────────────────────────────────

    @Slot(str, str)
    def explainCode(self, code: str, language: str = "python") -> None:
        schedule(self._run_action("explain", code, language))

    @Slot(str, str)
    def refactorCode(self, code: str, language: str = "python") -> None:
        schedule(self._run_action("refactor", code, language))

    @Slot(str, str)
    def generateTests(self, code: str, language: str = "python") -> None:
        schedule(self._run_action("tests", code, language))

    async def _run_action(self, action: str, code: str, language: str) -> None:
        from app.services.ai_service import AIService, ChatMessage

        self._messages.append(ChatMessageModel(
            role="user",
            content=f"/{action}\n```{language}\n{code[:4000]}\n```",
        ))
        self.messagesChanged.emit()

        ai = AIService()
        await ai.load_config()

        try:
            if action == "explain":
                result = await ai.explain_code(code, language)
            elif action == "refactor":
                result = await ai.refactor_code(code, language)
            elif action == "tests":
                result = await ai.generate_tests(code, language)
            else:
                result = "Unknown action."
        except Exception as e:
            result = f"Error: {e}"

        self._messages.append(ChatMessageModel(role="assistant", content=result))
        self.messagesChanged.emit()
        self.responseFinished.emit(result)

    # ── Config ───────────────────────────────────────────

    @Slot(str, str, str, float, int)
    def saveAiConfig(
        self, provider: str, model: str, endpoint: str,
        temperature: float = 0.2, max_tokens: int = 1024,
    ) -> None:
        schedule(self._save_ai_config(
            provider, model, endpoint, temperature, max_tokens,
        ))

    async def _save_ai_config(
        self, provider: str, model: str, endpoint: str,
        temperature: float, max_tokens: int,
    ) -> None:
        from app.services.ai_service import AIService
        ai = AIService()
        ai.configure(
            provider=provider, model=model, endpoint=endpoint,
            temperature=temperature, max_tokens=max_tokens,
        )
        await ai.save_config()
