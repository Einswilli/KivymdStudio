from __future__ import annotations

import html
import json
import re
from typing import Any

try:
    import ferrite

    HAS_FERRITE = True
except Exception:
    ferrite = None
    HAS_FERRITE = False


def render_hover(
    *,
    signature: str = "",
    documentation: str = "",
    description: str = "",
    language: str = "text",
) -> dict[str, Any]:
    if HAS_FERRITE and hasattr(ferrite, "format_hover"):
        try:
            return json.loads(
                ferrite.format_hover(signature, documentation, description, language)
            )
        except Exception:
            pass

    sections: list[dict[str, str]] = []
    if signature.strip():
        sections.append({
            "kind": "signature",
            "text": signature.strip(),
            "html": f"<pre style='margin:0; color:#DCDCAA;'>{html.escape(signature.strip())}</pre>",
        })
    if documentation.strip():
        sections.append({
            "kind": "documentation",
            "text": documentation.strip(),
            "html": _markdown_to_html(documentation.strip()),
        })
    if not sections and description.strip():
        sections.append({
            "kind": "description",
            "text": description.strip(),
            "html": _markdown_to_html(description.strip()),
        })

    return {
        "language": language,
        "body_html": "<br><br>".join(section["html"] for section in sections),
        "sections": sections,
    }


def _markdown_to_html(markdown: str) -> str:
    escaped = html.escape(markdown)
    escaped = re.sub(
        r"```([\s\S]*?)```",
        lambda match: f"<pre style='margin:0; color:#DCDCAA;'>{match.group(1).strip()}</pre>",
        escaped,
    )
    escaped = re.sub(r"`([^`]+)`", r"<span style='color:#DCDCAA;'>\1</span>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(
        r"^#{1,3}\s+(.*)$",
        r"<span style='color:#E5C07B; font-weight:600;'>\1</span>",
        escaped,
        flags=re.MULTILINE,
    )
    escaped = re.sub(r"^-\s+(.*)$", r"<span style='color:#9CA3AF;'>•</span> \1", escaped, flags=re.MULTILINE)
    return escaped.replace("\n", "<br>")
