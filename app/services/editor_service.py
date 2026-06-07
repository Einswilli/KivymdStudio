from __future__ import annotations

import re
import json
from dataclasses import dataclass

from app.services.language_service import LANGUAGE_KEYWORDS
from app.services.language_detection import detect_language

try:
    import ferrite

    HAS_FERRITE = True
except ImportError:
    HAS_FERRITE = False


TOKEN_KINDS = {
    "comment": "comment",
    "line_comment": "comment",
    "block_comment": "comment",
    "doc_comment": "comment",
    "inner_doc_comment": "comment",
    "outer_doc_comment": "comment",
    "string": "string",
    "string_content": "string",
    "string_start": "string",
    "string_end": "string",
    "string_fragment": "string",
    "escape_sequence": "string",
    "integer": "number",
    "integer_literal": "number",
    "integer_value": "number",
    "float": "number",
    "float_literal": "number",
    "number": "number",
    "number_literal": "number",
    "true": "keyword",
    "false": "keyword",
    "null": "keyword",
    "none": "keyword",
    "boolean": "type",
    "primitive_type": "type",
    "predefined_type": "type",
    "identifier": "identifier",
    "module": "module",
    "module_name": "module",
    "namespace": "module",
    "type_identifier": "type",
    "property_identifier": "property",
    "property_name": "property",
    "plain_value": "value",
    "attribute_value": "string",
    "tag_name": "type",
    "attribute_name": "property",
    "function_definition": "function",
    "function": "function",
    "method": "function",
    "class_definition": "class",
    "struct": "class",
    "enum": "class",
    "trait": "class",
    "decorator": "decorator",
    "import_statement": "keyword",
    "import_from_statement": "keyword",
    "return_statement": "keyword",
    "def": "keyword",
    "class": "keyword",
    "import": "keyword",
    "from": "keyword",
    "as": "keyword",
    "if": "keyword",
    "elif": "keyword",
    "else": "keyword",
    "for": "keyword",
    "while": "keyword",
    "try": "keyword",
    "except": "keyword",
    "finally": "keyword",
    "with": "keyword",
    "raise": "keyword",
    "return": "keyword",
    "yield": "keyword",
    "break": "keyword",
    "continue": "keyword",
    "in": "keyword",
    "not": "keyword",
    "and": "keyword",
    "or": "keyword",
    "is": "keyword",
    "lambda": "keyword",
    "pass": "keyword",
    "type": "type",
    "None": "keyword",
    "True": "keyword",
    "False": "keyword",
}

TREE_SITTER_TOKEN_KIND_ALIASES: dict[str, set[str]] = {
    "comment": {
        "comment", "line_comment", "block_comment", "doc_comment", "inner_doc_comment",
        "outer_doc_comment", "html_comment", "js_comment", "hash_bang_line", "shebang",
    },
    "string": {
        "string", "string_content", "string_start", "string_end", "string_fragment",
        "string_literal", "raw_string_literal", "interpreted_string_literal", "char_literal",
        "template_string", "template_substitution", "template_literal_type", "string_value",
        "quoted_attribute_value", "attribute_value", "raw_text", "regex", "regex_pattern",
        "regex_flags",
    },
    "number": {
        "integer", "integer_literal", "integer_value", "float", "float_literal",
        "float_value", "number", "number_literal", "negative_literal",
    },
    "keyword": {
        "true", "false", "null", "none", "undefined", "True", "False", "None",
        "if", "elif", "else", "for", "while", "loop", "match", "case", "switch",
        "default", "break", "continue", "return", "yield", "try", "except", "catch",
        "finally", "throw", "raise", "with", "async", "await", "function", "fn",
        "def", "lambda", "class", "struct", "enum", "trait", "interface", "impl",
        "type", "const", "let", "var", "static", "pub", "private", "protected",
        "public", "import", "from", "as", "export", "extends", "implements",
        "use", "mod", "crate", "self", "Self", "super", "this", "new", "in",
        "is", "not", "and", "or", "move", "mut", "ref", "unsafe", "where",
        "extern", "abstract", "readonly", "override", "satisfies", "asserts",
        "delete", "do", "typeof", "void", "instanceof", "debugger", "pass",
        "global", "nonlocal", "del", "yield_expression", "return_expression",
        "break_expression", "continue_expression",
    },
    "type": {
        "type", "type_identifier", "scoped_type_identifier", "primitive_type",
        "predefined_type", "primary_type", "object_type", "array_type", "tuple_type",
        "union_type", "intersection_type", "generic_type", "generic_type_with_turbofish",
        "type_arguments", "type_argument", "type_parameter", "type_parameters",
        "type_annotation", "type_alias_declaration", "type_alias_statement",
        "type_item", "function_type", "constructor_type", "abstract_type",
        "bounded_type", "dynamic_type", "reference_type", "pointer_type",
        "never_type", "unit_type", "template_type", "literal_type", "conditional_type",
        "constraint", "default_type", "existential_type", "flow_maybe_type",
        "lookup_type", "mapped_type_clause", "optional_type", "rest_type",
        "readonly_type", "this_type", "infer_type", "index_type_query",
        "type_predicate", "type_predicate_annotation", "member_type",
        "constrained_type", "splat_type", "union_pattern",
    },
    "function": {
        "function", "function_name", "function_definition", "function_declaration",
        "function_expression", "function_item", "function_signature_item",
        "function_signature", "method", "method_definition", "method_signature",
        "abstract_method_signature", "call_expression", "call", "generic_function",
        "arrow_function", "generator_function", "generator_function_declaration",
        "closure_expression", "macro_invocation", "macro_definition",
    },
    "class": {
        "class_definition", "class_declaration", "abstract_class_declaration", "class",
        "struct", "struct_item", "enum", "enum_item", "enum_declaration",
        "enum_variant", "enum_variant_list", "trait", "trait_item",
        "interface_declaration", "interface_body", "impl_item", "union_item",
    },
    "decorator": {
        "decorator", "decorated_definition", "attribute_item",
        "inner_attribute_item", "meta",
    },
    "module": {
        "module", "module_name", "namespace", "namespace_name", "namespace_import",
        "namespace_export", "namespace_statement", "internal_module", "nested_identifier",
        "import_statement", "import_from_statement", "future_import_statement",
        "import_declaration", "import_clause", "import_specifier", "import_attribute",
        "import_alias", "import_require_clause", "named_imports", "export_statement",
        "export_clause", "export_specifier", "extern_crate_declaration",
        "use_declaration", "use_list", "scoped_use_list", "use_as_clause",
        "use_wildcard", "use_bounds", "mod_item",
    },
    "property": {
        "property_identifier", "private_property_identifier", "property_name",
        "property_signature", "field_identifier", "field_declaration",
        "field_declaration_list", "field_definition", "field_expression",
        "field_initializer", "field_initializer_list", "shorthand_field_identifier",
        "shorthand_field_initializer", "base_field_initializer", "pair", "key",
        "attribute_name", "computed_property_name", "public_field_definition",
        "member_expression", "meta_property", "subscript_expression", "index_signature",
    },
    "parameter": {
        "parameter", "parameters", "formal_parameters", "lambda_parameters",
        "closure_parameters", "self_parameter", "required_parameter",
        "optional_parameter", "rest_pattern", "rest_type", "default_parameter",
        "typed_parameter", "typed_default_parameter", "keyword_argument",
        "const_parameter", "lifetime_parameter", "variadic_parameter",
    },
    "variable": {
        "identifier", "statement_identifier", "shorthand_property_identifier",
        "shorthand_property_identifier_pattern", "variable_declaration",
        "variable_declarator", "let_declaration", "let_condition", "let_chain",
        "assignment", "assignment_expression", "augmented_assignment",
        "augmented_assignment_expression", "assignment_pattern", "token_binding_pattern",
        "captured_pattern", "field_pattern", "generic_pattern", "mut_pattern",
        "ref_pattern", "reference_pattern", "tuple_pattern", "list_pattern",
        "dict_pattern", "object_pattern", "array_pattern", "pattern",
    },
    "tag": {
        "tag_name", "start_tag", "end_tag", "self_closing_tag", "erroneous_end_tag",
        "erroneous_end_tag_name", "element", "script_element", "style_element",
        "jsx_opening_element", "jsx_closing_element", "jsx_self_closing_element",
        "jsx_element", "jsx_namespace_name",
    },
    "attribute": {
        "attribute_name", "attribute_selector", "jsx_attribute", "accessibility_modifier",
        "visibility_modifier", "function_modifiers", "mutable_specifier",
        "extern_modifier",
    },
    "selector": {
        "selector_query", "selectors", "class_selector", "id_selector",
        "pseudo_class_selector", "pseudo_element_selector", "attribute_selector",
        "child_selector", "descendant_selector", "sibling_selector",
        "adjacent_sibling_selector", "namespace_selector", "universal_selector",
        "nesting_selector", "class_name", "id_name",
    },
    "value": {
        "plain_value", "color_value", "grid_value", "unit", "important",
        "important_value", "feature_name", "keyframes_name", "html_character_reference",
        "entity", "text", "jsx_text", "boolean_literal",
    },
    "operator": {
        "binary_operator", "boolean_operator", "comparison_operator", "not_operator",
        "unary_operator", "binary_expression", "unary_expression", "ternary_expression",
        "update_expression", "range_expression", "range_pattern", "type_cast_expression",
        "compound_assignment_expr", "optional_chain", "non_null_expression",
        "as_expression", "satisfies_expression", "await_expression",
    },
}

for ember_kind, tree_sitter_kinds in TREE_SITTER_TOKEN_KIND_ALIASES.items():
    TOKEN_KINDS.update({kind: ember_kind for kind in tree_sitter_kinds})

PUNCTUATION_KINDS = {
    "(", ")", "{", "}", "[", "]", "<", ">", "</", "/>", ".", ",", ":", ";", "=",
    "+", "-", "*", "/", "%", "!", "?", "&", "|", "^", "~", "->", "=>", "::",
    "==", "===", "!=", "!==", "<=", ">=", "&&", "||", "+=", "-=", "*=", "/=",
    "%=", "&=", "|=", "^=", "**", "**=", "//", "//=", "..", "...", "..=", "=>",
    "?.", "??", "??=", "@", "#", "$", "\\", "\"", "'", "`",
}

MAX_HIGHLIGHT_LINE_LENGTH = 800
MAX_SPANS_PER_LINE = 160

PY_KEYWORDS = {
    "False",
    "None",
    "True",
    "and",
    "as",
    "assert",
    "async",
    "await",
    "break",
    "class",
    "continue",
    "def",
    "del",
    "elif",
    "else",
    "except",
    "finally",
    "for",
    "from",
    "global",
    "if",
    "import",
    "in",
    "is",
    "lambda",
    "nonlocal",
    "not",
    "or",
    "pass",
    "raise",
    "return",
    "try",
    "while",
    "with",
    "yield",
}

JS_KEYWORDS = {
    "break",
    "case",
    "catch",
    "class",
    "const",
    "continue",
    "default",
    "delete",
    "do",
    "else",
    "export",
    "extends",
    "finally",
    "for",
    "from",
    "function",
    "if",
    "import",
    "in",
    "instanceof",
    "let",
    "new",
    "return",
    "super",
    "switch",
    "this",
    "throw",
    "try",
    "typeof",
    "var",
    "void",
    "while",
    "with",
    "yield",
    "async",
    "await",
}

TS_KEYWORDS = LANGUAGE_KEYWORDS["typescript"]
QML_KEYWORDS = LANGUAGE_KEYWORDS["qml"]
KIVY_KEYWORDS = LANGUAGE_KEYWORDS["kivy"]
JSON_KEYWORDS = LANGUAGE_KEYWORDS["json"]
YAML_KEYWORDS = LANGUAGE_KEYWORDS["yaml"]
TOML_KEYWORDS = LANGUAGE_KEYWORDS["toml"]
HTML_KEYWORDS = LANGUAGE_KEYWORDS["html"]
CSS_KEYWORDS = LANGUAGE_KEYWORDS["css"]
GO_KEYWORDS = LANGUAGE_KEYWORDS["go"]
JAVA_KEYWORDS = LANGUAGE_KEYWORDS["java"]
RUBY_KEYWORDS = LANGUAGE_KEYWORDS["ruby"]

RUST_KEYWORDS = {
    "as",
    "break",
    "const",
    "continue",
    "crate",
    "else",
    "enum",
    "extern",
    "false",
    "fn",
    "for",
    "if",
    "impl",
    "in",
    "let",
    "loop",
    "match",
    "mod",
    "move",
    "mut",
    "pub",
    "ref",
    "return",
    "self",
    "Self",
    "static",
    "struct",
    "super",
    "trait",
    "true",
    "type",
    "unsafe",
    "use",
    "where",
    "while",
}

PY_BUILTIN_TYPES = {
    "bool",
    "bytearray",
    "bytes",
    "complex",
    "dict",
    "float",
    "frozenset",
    "int",
    "list",
    "object",
    "set",
    "str",
    "tuple",
    "type",
}

PY_BUILTINS = {
    "abs",
    "all",
    "any",
    "bin",
    "callable",
    "chr",
    "classmethod",
    "compile",
    "delattr",
    "dir",
    "divmod",
    "enumerate",
    "eval",
    "exec",
    "filter",
    "format",
    "getattr",
    "globals",
    "hasattr",
    "hash",
    "help",
    "hex",
    "id",
    "input",
    "isinstance",
    "issubclass",
    "iter",
    "len",
    "locals",
    "map",
    "max",
    "min",
    "next",
    "oct",
    "open",
    "ord",
    "pow",
    "print",
    "property",
    "range",
    "repr",
    "reversed",
    "round",
    "slice",
    "sorted",
    "staticmethod",
    "sum",
    "super",
    "vars",
    "zip",
    "__import__",
}

_PY_TOKEN_RE = re.compile(
    r"(?P<comment>#.*$)"
    r"|(?P<string>(?:'''[^']*'''|\"\"\"[^\"]*\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"))"
    r"|(?P<number>\b\d+(?:\.\d+)?\b)"
    r"|(?P<decorator>@[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<identifier>\b[A-Za-z_][A-Za-z0-9_]*\b)"
    r"|(?P<operator>[+\-*/%=<>!&|^~:.,;(){}\[\]])"
)

_GENERIC_TOKEN_RE = re.compile(
    r"(?P<comment>//.*$|#.*$)"
    r"|(?P<string>'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"|`(?:\\.|[^`\\])*`)"
    r"|(?P<number>\b\d+(?:\.\d+)?\b)"
    r"|(?P<decorator>@[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<identifier>\b[A-Za-z_][A-Za-z0-9_]*\b)"
    r"|(?P<operator>[+\-*/%=<>!&|^~:.,;(){}\[\]])"
)


@dataclass(frozen=True)
class Token:
    start: int
    end: int
    kind: str
    raw_kind: str = ""

    def to_qml(self) -> dict:
        output = {"start": self.start, "end": self.end, "kind": self.kind}
        if self.raw_kind:
            output["rawKind"] = self.raw_kind
        return output


def tokenize_line(text: str, language: str = "python") -> list[Token]:
    if not text.strip():
        return []
    if len(text) > MAX_HIGHLIGHT_LINE_LENGTH:
        return []
    if language == "python":
        return _fallback_python_tokens(text)
    if language == "javascript":
        return _fallback_generic_tokens(text, JS_KEYWORDS)
    if language == "typescript":
        return _fallback_generic_tokens(text, TS_KEYWORDS)
    if language == "rust":
        return _fallback_generic_tokens(text, RUST_KEYWORDS)
    if language == "qml":
        return _fallback_generic_tokens(text, QML_KEYWORDS)
    if language == "kivy":
        return _fallback_generic_tokens(text, KIVY_KEYWORDS)
    if language == "json":
        return _fallback_generic_tokens(text, JSON_KEYWORDS)
    if language == "yaml":
        return _fallback_generic_tokens(text, YAML_KEYWORDS)
    if language == "toml":
        return _fallback_generic_tokens(text, TOML_KEYWORDS)
    if language == "html":
        return _fallback_generic_tokens(text, HTML_KEYWORDS)
    if language == "css":
        return _fallback_generic_tokens(text, CSS_KEYWORDS)
    if language == "go":
        return _fallback_generic_tokens(text, GO_KEYWORDS)
    if language == "java":
        return _fallback_generic_tokens(text, JAVA_KEYWORDS)
    if language == "ruby":
        return _fallback_generic_tokens(text, RUBY_KEYWORDS)
    if language in {"markdown", "cpp", "c", "text"}:
        return _fallback_generic_tokens(text, set())
    return _fallback_generic_tokens(text, set())


def tokenize_document(text: str, language: str = "python") -> dict[int, list[Token]]:
    if not text.strip():
        return {}
    if not HAS_FERRITE:
        return {}
    try:
        if hasattr(ferrite, "supported_languages") and language not in set(ferrite.supported_languages()):
            return {}
        raw_tokens = json.loads(ferrite.highlight(text, language))
    except Exception:
        return {}

    by_line: dict[int, list[Token]] = {}
    for item in raw_tokens:
        try:
            line_index = max(0, int(item["line"]) - 1)
            start = max(0, int(item["start"]))
            end = max(start, int(item["end"]))
            kind = normalize_token_kind(str(item["kind"]))
            raw_kind = str(item.get("raw_kind") or item["kind"])
            by_line.setdefault(line_index, []).append(Token(start, end, kind, raw_kind))
        except Exception:
            continue
    return by_line


def normalize_token_kind(kind: str) -> str:
    if kind in TOKEN_KINDS:
        return TOKEN_KINDS[kind]
    if kind in PUNCTUATION_KINDS:
        return "operator"
    return kind


def normalize_line_tokens(
    text: str,
    tokens: list[Token],
    language: str,
    imported_names: set[str] | None = None,
) -> list[Token]:
    if not tokens:
        return []

    imported_names = imported_names or set()
    normalized = [
        Token(token.start, token.end, normalize_token_kind(token.kind), token.raw_kind)
        for token in tokens
    ]
    normalized = _normalize_comment_line(text, normalized, language)
    normalized = _normalize_string_ranges(text, normalized)
    result: list[Token] = []
    previous_word = ""
    decorator_limit = -1
    if language == "python" and text.lstrip().startswith("@"):
        decorator_start = text.find("@")
        decorator_call_start = text.find("(", decorator_start)
        decorator_limit = decorator_call_start if decorator_call_start >= 0 else len(text)

    for index, token in enumerate(normalized):
        value = text[token.start:token.end]
        kind = token.kind
        before = text[:token.start]
        after = text[token.end:]
        next_char = after.lstrip()[:1]
        previous_non_space = before.rstrip()[-1:] if before.rstrip() else ""

        if language == "python" and decorator_limit >= 0 and token.start < decorator_limit and value.strip():
            kind = "decorator"
        elif language == "json" and kind == "string":
            kind = "property" if _is_json_key(text, token.end) else "string"
        elif language in {"html", "xml"}:
            if kind == "type":
                kind = "tag"
            elif kind == "property":
                kind = "attribute"
        elif language == "css":
            if kind == "type":
                kind = "selector"
            elif kind == "value":
                kind = "string"
            elif kind in {"identifier", "variable"} and re.search(r"(?:^|[\s,{])(?:\.|#)[A-Za-z0-9_-]*$", before):
                kind = "selector"
        elif language in {"typescript", "javascript"}:
            if value in {"string", "number", "boolean", "any", "unknown", "void", "never"}:
                kind = "type"
            elif kind in {"identifier", "variable"} and re.search(r"\b(?:function|class|interface)\s+$", before):
                kind = "function" if re.search(r"\bfunction\s+$", before) else "class"
            elif kind in {"identifier", "variable"} and re.search(r"\b(?:type|enum)\s+$", before):
                kind = "type"
        elif language == "rust":
            if kind in {"identifier", "variable"} and (previous_word in {"fn"} or re.search(r"\bfn\s+$", before)):
                kind = "function"
            elif kind in {"identifier", "variable"} and (
                previous_word in {"struct", "enum", "trait", "impl", "type"}
                or re.search(r"\b(?:struct|enum|trait|impl|type)\s+$", before)
            ):
                kind = "type"
        elif language == "python":
            if value in PY_BUILTIN_TYPES:
                kind = "type"
            elif value in PY_BUILTINS:
                kind = "builtin"
            elif kind in {"identifier", "variable"} and (previous_word == "def" or re.search(r"\bdef\s+$", before)):
                kind = "function"
            elif kind in {"identifier", "variable"} and (previous_word == "class" or re.search(r"\bclass\s+$", before)):
                kind = "class"

        if kind in {"identifier", "variable"} and next_char == "(":
            kind = "class" if value[:1].isupper() else "function"
        elif kind in {"identifier", "variable"} and value in imported_names:
            kind = "module"
        elif kind in {"identifier", "variable"} and previous_word in {"function"}:
            kind = "function"
        elif kind in {"identifier", "variable"} and previous_word in {"class", "interface"}:
            kind = "class"
        elif kind in {"identifier", "variable"} and _is_import_identifier(text, token, language):
            kind = "module"
        elif kind in {"identifier", "variable"} and previous_non_space == ".":
            kind = "property"

        if value.strip():
            previous_word = value if kind == "keyword" else ""

        result.append(Token(token.start, token.end, kind, token.raw_kind))

    return result


def _normalize_comment_line(text: str, tokens: list[Token], language: str) -> list[Token]:
    stripped = text.lstrip()
    leading = len(text) - len(stripped)
    comment_prefixes = ("//", "///", "//!") if language in {"rust", "javascript", "typescript", "go", "java"} else ()
    if comment_prefixes and stripped.startswith(comment_prefixes):
        return [Token(leading, len(text), "comment")]
    return tokens


def _normalize_string_ranges(text: str, tokens: list[Token]) -> list[Token]:
    if not tokens:
        return tokens
    quote_ranges: list[tuple[int, int]] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char not in {"'", '"', "`"}:
            index += 1
            continue
        start = index
        index += 1
        escaped = False
        while index < len(text):
            current = text[index]
            if escaped:
                escaped = False
            elif current == "\\":
                escaped = True
            elif current == char:
                index += 1
                quote_ranges.append((start, index))
                break
            index += 1
        else:
            quote_ranges.append((start, len(text)))
    if not quote_ranges:
        return tokens
    normalized: list[Token] = [Token(start, end, "string") for start, end in quote_ranges]
    for token in tokens:
        if any(token.start >= start and token.end <= end for start, end in quote_ranges):
            continue
        normalized.append(token)
    return sorted(normalized, key=lambda item: (item.start, item.end))


def _is_import_identifier(text: str, token: Token, language: str) -> bool:
    if language == "python":
        before = text[:token.start]
        return bool(re.search(r"^\s*(?:from|import)\s+[\w.,\s]*$", before))
    if language == "rust":
        before = text[:token.start]
        return bool(re.search(r"^\s*use\s+[\w:,\s{}*]*$", before))
    if language in {"javascript", "typescript"}:
        before = text[:token.start]
        after = text[token.end:]
        return (
            bool(re.search(r"^\s*import\s+[\w\s{},*]*$", before))
            or bool(re.search(r"\bfrom\s*$", before))
            or (text.lstrip().startswith("import") and after.lstrip().startswith("from"))
        )
    if language in {"go", "java"}:
        before = text[:token.start]
        return bool(re.search(r"^\s*import\s+[\w.\s]*$", before))
    return False


def _is_json_key(text: str, token_end: int) -> bool:
    index = token_end
    if index < len(text) and text[index:index + 1] in {"\"", "'"}:
        index += 1
    while index < len(text) and text[index].isspace():
        index += 1
    return index < len(text) and text[index] == ":"


def _collect_imported_names(text: str, language: str) -> set[str]:
    names: set[str] = set()
    if language == "python":
        for line in text.splitlines():
            stripped = line.strip()
            import_match = re.match(r"import\s+(.+)$", stripped)
            from_match = re.match(r"from\s+([\w.]+)\s+import\s+(.+)$", stripped)
            if import_match:
                for part in import_match.group(1).split(","):
                    name = part.strip().split(" as ")[-1].strip()
                    if name:
                        names.add(name.split(".")[0])
            elif from_match:
                module = from_match.group(1).split(".")[0]
                if module:
                    names.add(module)
                for part in from_match.group(2).split(","):
                    name = part.strip().split(" as ")[-1].strip()
                    if name and name != "*":
                        names.add(name)
    elif language == "rust":
        for match in re.finditer(r"\buse\s+([^;]+)", text):
            for name in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", match.group(1)):
                if name not in RUST_KEYWORDS:
                    names.add(name)
    elif language in {"javascript", "typescript", "tsx"}:
        for match in re.finditer(r"\bimport\s+(.+?)\s+from\s+['\"]", text):
            for name in re.findall(r"[A-Za-z_$][A-Za-z0-9_$]*", match.group(1)):
                if name not in JS_KEYWORDS and name not in {"as"}:
                    names.add(name)
    return names


def _fallback_python_tokens(text: str) -> list[Token]:
    tokens: list[Token] = []
    previous_keyword = ""
    for match in _PY_TOKEN_RE.finditer(text):
        kind = match.lastgroup or "default"
        value = match.group(kind)
        if kind == "identifier":
            if value in PY_KEYWORDS:
                kind = "keyword"
                previous_keyword = value
            elif previous_keyword == "def":
                kind = "function"
                previous_keyword = ""
            elif previous_keyword == "class":
                kind = "class"
                previous_keyword = ""
            else:
                previous_keyword = ""
        elif kind == "decorator":
            kind = "decorator"
            previous_keyword = ""
        elif kind != "operator":
            previous_keyword = ""
        tokens.append(Token(match.start(), match.end(), kind))
        if kind == "comment":
            break
    return tokens


def _fallback_generic_tokens(text: str, keywords: set[str]) -> list[Token]:
    tokens: list[Token] = []
    previous_keyword = ""
    for match in _GENERIC_TOKEN_RE.finditer(text):
        kind = match.lastgroup or "default"
        value = match.group(kind)
        if kind == "identifier":
            if value in keywords:
                kind = "keyword"
                previous_keyword = value
            elif previous_keyword in {"function", "fn"}:
                kind = "function"
                previous_keyword = ""
            elif previous_keyword in {"class", "struct", "enum", "trait"}:
                kind = "class"
                previous_keyword = ""
            else:
                previous_keyword = ""
        elif kind != "operator":
            previous_keyword = ""
        tokens.append(Token(match.start(), match.end(), kind))
        if kind == "comment":
            break
    return tokens


def build_spans(text: str, tokens: list[Token]) -> list[dict]:
    if not text:
        return [{"start": 0, "end": 0, "kind": "default", "text": " "}]
    if not tokens:
        return [{"start": 0, "end": len(text), "kind": "default", "text": text}]

    spans: list[dict] = []
    position = 0
    for token in sorted(tokens, key=lambda item: (item.start, item.end)):
        if len(spans) >= MAX_SPANS_PER_LINE:
            break
        start = max(0, min(token.start, len(text)))
        end = max(start, min(token.end, len(text)))
        if end <= position:
            continue
        if start < position:
            start = position
        if start > position:
            spans.append({
                "start": position,
                "end": start,
                "kind": "default",
                "text": text[position:start],
            })
        if end > start:
            spans.append({
                "start": start,
                "end": end,
                "kind": token.kind,
                "text": text[start:end],
            })
        position = max(position, end)
    if position < len(text):
        spans.append({
            "start": position,
            "end": len(text),
            "kind": "default",
            "text": text[position:],
        })
    return spans or [{"start": 0, "end": len(text), "kind": "default", "text": text}]


def build_line_items(text: str, language: str = "python") -> list[dict]:
    lines = text.split("\n")
    ferrite_tokens = tokenize_document(text, language)
    imported_names = _collect_imported_names(text, language)
    items = []
    for index, line in enumerate(lines):
        tokens = normalize_line_tokens(
            line,
            ferrite_tokens.get(index) or tokenize_line(line, language),
            language,
            imported_names,
        )
        items.append({
            "lineNumber": index + 1,
            "text": line,
            "tokens": [token.to_qml() for token in tokens],
            "spans": build_spans(line, tokens),
            "diagnostics": [],
            "decorations": [],
        })
    return items
