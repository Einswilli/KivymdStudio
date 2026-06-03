from __future__ import annotations

from pathlib import Path

LANGUAGE_EXTENSIONS: dict[str, tuple[str, ...]] = {
    "python": ("py", "pyi", "pyw", "pyx", "pxd", "pxi"),
    "kivy": ("kv",),
    "qml": ("qml",),
    "javascript": ("js", "mjs", "cjs", "jsx"),
    "typescript": ("ts", "mts", "cts", "tsx"),
    "json": ("json", "jsonc", "json5", "ipynb"),
    "yaml": ("yaml", "yml"),
    "toml": ("toml", "tml"),
    "markdown": ("md", "markdown", "mdown", "mkd", "mdx"),
    "html": ("html", "htm", "xhtml"),
    "css": ("css", "scss", "sass", "less"),
    "rust": ("rs",),
    "cpp": ("cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "ipp", "ixx"),
    "c": ("c", "h"),
    "go": ("go",),
    "java": ("java",),
    "ruby": ("rb", "rake", "gemspec"),
    "shell": ("sh", "bash", "zsh", "fish", "ksh", "bats"),
    "powershell": ("ps1", "psm1", "psd1"),
    "xml": ("xml", "svg", "xaml", "ui"),
}

FILENAME_LANGUAGES: dict[str, str] = {
    ".bashrc": "shell",
    ".zshrc": "shell",
    ".profile": "shell",
    "bashrc": "shell",
    "containerfile": "dockerfile",
    "dockerfile": "dockerfile",
    "gnumakefile": "makefile",
    "makefile": "makefile",
    "rakefile": "ruby",
}

EXTENSION_TO_LANGUAGE: dict[str, str] = {
    extension: language
    for language, extensions in LANGUAGE_EXTENSIONS.items()
    for extension in extensions
}


def detect_language(path: str) -> str:
    file_name = Path(path).name.lower()
    if file_name in FILENAME_LANGUAGES:
        return FILENAME_LANGUAGES[file_name]

    suffixes = [suffix[1:].lower() for suffix in Path(path).suffixes if len(suffix) > 1]
    if not suffixes:
        return "text"

    if len(suffixes) >= 2 and suffixes[-2:] == ["d", "ts"]:
        return "typescript"

    return EXTENSION_TO_LANGUAGE.get(suffixes[-1], "text")


def supported_extensions(language: str | None = None) -> tuple[str, ...]:
    if language is not None:
        return LANGUAGE_EXTENSIONS.get(language, ())
    return tuple(sorted(EXTENSION_TO_LANGUAGE))
