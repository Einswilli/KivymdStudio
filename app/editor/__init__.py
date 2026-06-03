"""
Code editor module — custom widget built on QSyntaxHighlighter + overlays.

Architecture:
    CodeEditor.qml  ←→  EditorDocument (Python)  ←→  SyntaxHighlighter (ferrite)
         ↑                        ↑
    Overlays (LineNumbers, InlineSuggestion, Diagnostics)
"""

from app.editor.highlighter import SyntaxHighlighter, TOKEN_COLORS, HAS_FERRITE
from app.editor.document import EditorDocument

__all__ = ["SyntaxHighlighter", "EditorDocument", "TOKEN_COLORS", "HAS_FERRITE"]
