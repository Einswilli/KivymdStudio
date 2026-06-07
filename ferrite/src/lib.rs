use pyo3::exceptions::PyValueError;
use pyo3::prelude::*;
use serde::Serialize;
use tree_sitter::{Language, Node, Parser};

#[derive(Debug, Clone, Serialize)]
struct Token {
    start: usize,
    end: usize,
    kind: String,
    raw_kind: String,
}

#[derive(Debug, Clone, Serialize)]
struct LineToken {
    line: usize,
    start: usize,
    end: usize,
    kind: String,
    raw_kind: String,
}

#[derive(Debug, Clone, Serialize)]
struct Symbol {
    name: String,
    kind: String,
    start: usize,
    end: usize,
    line: usize,
}

#[derive(Debug, Clone, Serialize)]
struct HoverSection {
    kind: String,
    text: String,
    html: String,
}

#[derive(Debug, Clone, Serialize)]
struct HoverDocument {
    language: String,
    body_html: String,
    sections: Vec<HoverSection>,
}

fn language_for(name: &str) -> Option<Language> {
    match normalize_language(name).as_str() {
        "python" => Some(tree_sitter_python::LANGUAGE.into()),
        "rust" => Some(tree_sitter_rust::LANGUAGE.into()),
        "javascript" => Some(tree_sitter_javascript::LANGUAGE.into()),
        "typescript" => Some(tree_sitter_typescript::LANGUAGE_TYPESCRIPT.into()),
        "tsx" => Some(tree_sitter_typescript::LANGUAGE_TSX.into()),
        "json" => Some(tree_sitter_json::LANGUAGE.into()),
        "html" => Some(tree_sitter_html::LANGUAGE.into()),
        "css" => Some(tree_sitter_css::LANGUAGE.into()),
        _ => None,
    }
}

fn normalize_language(name: &str) -> String {
    match name.trim().to_ascii_lowercase().as_str() {
        "py" => "python".to_string(),
        "rs" => "rust".to_string(),
        "js" | "jsx" | "mjs" | "cjs" => "javascript".to_string(),
        "ts" => "typescript".to_string(),
        "html" | "htm" => "html".to_string(),
        "scss" | "sass" => "css".to_string(),
        other => other.to_string(),
    }
}

fn parser_for(language: &str) -> PyResult<Parser> {
    let lang = language_for(language).ok_or_else(|| {
        PyValueError::new_err(format!(
            "Unsupported language '{}'. Supported: python, rust, javascript, typescript, tsx, json, html, css",
            language
        ))
    })?;
    let mut parser = Parser::new();
    parser
        .set_language(&lang)
        .map_err(|err| PyValueError::new_err(format!("Error setting parser language: {err}")))?;
    Ok(parser)
}

fn parse_tree<'a>(code: &'a str, language: &str) -> PyResult<tree_sitter::Tree> {
    let mut parser = parser_for(language)?;
    parser
        .parse(code, None)
        .ok_or_else(|| PyValueError::new_err("Error parsing code"))
}

fn collect_tokens(code: &str, language: &str) -> PyResult<Vec<Token>> {
    let tree = parse_tree(code, language)?;
    let mut cursor = tree.walk();
    let mut stack = vec![tree.root_node()];
    let mut tokens = Vec::new();

    while let Some(node) = stack.pop() {
        if should_emit_token(node) {
            let raw_kind = node.kind().to_string();
            tokens.push(Token {
                start: node.start_byte(),
                end: node.end_byte(),
                kind: ember_token_kind_for_node(node),
                raw_kind,
            });
            continue;
        }
        for child in node.children(&mut cursor) {
            stack.push(child);
        }
    }

    tokens.sort_by_key(|token| (token.start, token.end));
    Ok(tokens)
}

fn should_emit_token(node: Node) -> bool {
    if node.start_byte() == node.end_byte() {
        return false;
    }
    if matches!(
        node.kind(),
        "comment"
            | "line_comment"
            | "block_comment"
            | "doc_comment"
            | "inner_doc_comment"
            | "outer_doc_comment"
            | "html_comment"
            | "js_comment"
            | "hash_bang_line"
            | "shebang"
            | "string"
            | "string_literal"
            | "raw_string_literal"
            | "interpreted_string_literal"
            | "template_string"
            | "string_value"
            | "quoted_attribute_value"
            | "attribute_value"
            | "regex"
    ) {
        return true;
    }
    node.child_count() == 0
}

fn ember_token_kind_for_node(node: Node) -> String {
    let kind = node.kind();
    if matches!(
        kind,
        "identifier" | "property_identifier" | "field_identifier" | "type_identifier"
    ) {
        if is_import_identifier(node) {
            return "module".to_string();
        }
        if is_named_child_of(
            node,
            &[
                "function_definition",
                "function_declaration",
                "function_item",
                "method_definition",
                "method_signature",
                "generator_function_declaration",
            ],
        ) {
            return "function".to_string();
        }
        if is_named_child_of(
            node,
            &[
                "class_definition",
                "class_declaration",
                "struct_item",
                "enum_item",
                "trait_item",
                "interface_declaration",
            ],
        ) {
            return "class".to_string();
        }
        if is_named_child_of(
            node,
            &[
                "type_alias_declaration",
                "type_item",
            ],
        ) {
            return "type".to_string();
        }
    }
    ember_token_kind(kind)
}

fn is_named_child_of(node: Node, parent_kinds: &[&str]) -> bool {
    let Some(parent) = node.parent() else {
        return false;
    };
    if !parent_kinds.contains(&parent.kind()) {
        return false;
    }
    parent
        .child_by_field_name("name")
        .map(|name| name.id() == node.id())
        .unwrap_or(false)
}

fn is_import_identifier(node: Node) -> bool {
    let mut current = node;
    while let Some(parent) = current.parent() {
        if matches!(
            parent.kind(),
            "import_statement"
                | "import_from_statement"
                | "future_import_statement"
                | "import_declaration"
                | "import_clause"
                | "namespace_import"
                | "named_imports"
                | "import_specifier"
                | "use_declaration"
                | "use_list"
                | "scoped_use_list"
                | "use_as_clause"
                | "extern_crate_declaration"
        ) {
            return true;
        }
        current = parent;
    }
    false
}

fn ember_token_kind(kind: &str) -> String {
    match kind {
        "comment" | "line_comment" | "block_comment" | "doc_comment" | "inner_doc_comment"
        | "outer_doc_comment" | "html_comment" | "js_comment" | "hash_bang_line" | "shebang" => {
            "comment"
        }
        "string" | "string_content" | "string_start" | "string_end" | "string_fragment"
        | "string_literal" | "raw_string_literal" | "interpreted_string_literal" | "char_literal"
        | "template_string" | "template_substitution" | "template_literal_type"
        | "string_value" | "quoted_attribute_value" | "attribute_value" | "raw_text"
        | "regex" | "regex_pattern" | "regex_flags" | "escape_sequence" => "string",
        "integer" | "integer_literal" | "integer_value" | "float" | "float_literal"
        | "float_value" | "number" | "number_literal" | "negative_literal" => "number",
        "true" | "false" | "null" | "none" | "undefined" | "True" | "False" | "None"
        | "if" | "elif" | "else" | "for" | "while" | "loop" | "match" | "case"
        | "switch" | "default" | "break" | "continue" | "return" | "yield" | "try"
        | "except" | "catch" | "finally" | "throw" | "raise" | "with" | "async"
        | "await" | "function" | "fn" | "def" | "lambda" | "class" | "struct"
        | "enum" | "trait" | "interface" | "impl" | "type" | "const" | "let" | "var"
        | "static" | "pub" | "private" | "protected" | "public" | "import" | "from"
        | "as" | "export" | "extends" | "implements" | "use" | "mod" | "crate"
        | "self" | "Self" | "super" | "this" | "new" | "in" | "is" | "not"
        | "and" | "or" | "move" | "mut" | "ref" | "unsafe" | "where" | "extern"
        | "abstract" | "readonly" | "override" | "satisfies" | "asserts" | "delete"
        | "do" | "typeof" | "void" | "instanceof" | "debugger" | "pass" | "global"
        | "nonlocal" | "del" | "yield_expression" | "return_expression"
        | "break_expression" | "continue_expression" => "keyword",
        "type_identifier" | "scoped_type_identifier" | "primitive_type" | "predefined_type"
        | "primary_type" | "object_type" | "array_type" | "tuple_type" | "union_type"
        | "intersection_type" | "generic_type" | "generic_type_with_turbofish"
        | "type_arguments" | "type_argument" | "type_parameter" | "type_parameters"
        | "type_annotation" | "type_alias_declaration" | "type_alias_statement"
        | "type_item" | "function_type" | "constructor_type" | "abstract_type"
        | "bounded_type" | "dynamic_type" | "reference_type" | "pointer_type"
        | "never_type" | "unit_type" | "template_type" | "literal_type"
        | "conditional_type" | "constraint" | "default_type" | "existential_type"
        | "flow_maybe_type" | "lookup_type" | "mapped_type_clause" | "optional_type"
        | "rest_type" | "readonly_type" | "this_type" | "infer_type"
        | "index_type_query" | "type_predicate" | "type_predicate_annotation"
        | "member_type" | "constrained_type" | "splat_type" | "union_pattern" => "type",
        "function_name" | "function_definition" | "function_declaration"
        | "function_expression" | "function_item" | "function_signature_item"
        | "function_signature" | "method" | "method_definition" | "method_signature"
        | "abstract_method_signature" | "call_expression" | "call" | "generic_function"
        | "arrow_function" | "generator_function" | "generator_function_declaration"
        | "closure_expression" | "macro_invocation" | "macro_definition" => "function",
        "class_definition" | "class_declaration" | "abstract_class_declaration" | "struct_item"
        | "enum_item" | "enum_declaration" | "enum_variant" | "enum_variant_list"
        | "trait_item" | "interface_declaration" | "interface_body" | "impl_item"
        | "union_item" => "class",
        "decorator" | "decorated_definition" | "attribute_item" | "inner_attribute_item"
        | "meta" => "decorator",
        "module" | "module_name" | "namespace" | "namespace_name" | "namespace_import"
        | "namespace_export" | "namespace_statement" | "internal_module" | "nested_identifier"
        | "import_statement" | "import_from_statement" | "future_import_statement"
        | "import_declaration" | "import_clause" | "import_specifier" | "import_attribute"
        | "import_alias" | "import_require_clause" | "named_imports" | "export_statement"
        | "export_clause" | "export_specifier" | "extern_crate_declaration"
        | "use_declaration" | "use_list" | "scoped_use_list" | "use_as_clause"
        | "use_wildcard" | "use_bounds" | "mod_item" => "module",
        "property_identifier" | "private_property_identifier" | "property_name"
        | "property_signature" | "field_identifier" | "field_declaration"
        | "field_declaration_list" | "field_definition" | "field_expression"
        | "field_initializer" | "field_initializer_list" | "shorthand_field_identifier"
        | "shorthand_field_initializer" | "base_field_initializer" | "pair" | "key"
        | "computed_property_name" | "public_field_definition"
        | "member_expression" | "meta_property" | "subscript_expression" | "index_signature" => {
            "property"
        }
        "parameter" | "parameters" | "formal_parameters" | "lambda_parameters"
        | "closure_parameters" | "self_parameter" | "required_parameter" | "optional_parameter"
        | "rest_pattern" | "default_parameter" | "typed_parameter" | "typed_default_parameter"
        | "keyword_argument" | "const_parameter" | "lifetime_parameter" | "variadic_parameter" => {
            "parameter"
        }
        "identifier" | "statement_identifier" | "shorthand_property_identifier"
        | "shorthand_property_identifier_pattern" | "variable_declaration" | "variable_declarator"
        | "let_declaration" | "let_condition" | "let_chain" | "assignment"
        | "assignment_expression" | "augmented_assignment" | "augmented_assignment_expression"
        | "assignment_pattern" | "token_binding_pattern" | "captured_pattern" | "field_pattern"
        | "generic_pattern" | "mut_pattern" | "ref_pattern" | "reference_pattern"
        | "tuple_pattern" | "list_pattern" | "dict_pattern" | "object_pattern" | "array_pattern"
        | "pattern" => "variable",
        "tag_name" | "start_tag" | "end_tag" | "self_closing_tag" | "erroneous_end_tag"
        | "erroneous_end_tag_name" | "element" | "script_element" | "style_element"
        | "jsx_opening_element" | "jsx_closing_element" | "jsx_self_closing_element"
        | "jsx_element" | "jsx_namespace_name" => "tag",
        "attribute_name" | "attribute_selector" | "jsx_attribute" | "accessibility_modifier"
        | "visibility_modifier" | "function_modifiers" | "mutable_specifier" | "extern_modifier" => {
            "attribute"
        }
        "selector_query" | "selectors" | "class_selector" | "id_selector"
        | "pseudo_class_selector" | "pseudo_element_selector" | "child_selector"
        | "descendant_selector" | "sibling_selector" | "adjacent_sibling_selector"
        | "namespace_selector" | "universal_selector" | "nesting_selector" | "class_name"
        | "id_name" => "selector",
        "plain_value" | "color_value" | "grid_value" | "unit" | "important"
        | "important_value" | "feature_name" | "keyframes_name" | "html_character_reference"
        | "entity" | "text" | "jsx_text" | "boolean_literal" => "value",
        "binary_operator" | "boolean_operator" | "comparison_operator" | "not_operator"
        | "unary_operator" | "binary_expression" | "unary_expression" | "ternary_expression"
        | "update_expression" | "range_expression" | "range_pattern" | "type_cast_expression"
        | "compound_assignment_expr" | "optional_chain" | "non_null_expression"
        | "as_expression" | "satisfies_expression" | "await_expression" => "operator",
        other if is_punctuation_kind(other) => "operator",
        _ => kind,
    }
    .to_string()
}

fn is_punctuation_kind(kind: &str) -> bool {
    matches!(
        kind,
        "(" | ")" | "{" | "}" | "[" | "]" | "<" | ">" | "</" | "/>" | "." | ","
            | ":" | ";" | "=" | "+" | "-" | "*" | "/" | "%" | "!" | "?" | "&" | "|"
            | "^" | "~" | "->" | "=>" | "::" | "==" | "===" | "!=" | "!==" | "<="
            | ">=" | "&&" | "||" | "+=" | "-=" | "*=" | "/=" | "%=" | "&=" | "|="
            | "^=" | "**" | "**=" | "//" | "//=" | ".." | "..." | "..=" | "?." | "??"
            | "??=" | "@" | "#" | "$" | "\\" | "\"" | "'" | "`"
    )
}

fn byte_to_line_and_col(code: &str, byte: usize) -> (usize, usize) {
    let clamped = byte.min(code.len());
    let before = &code[..clamped];
    let line = before.bytes().filter(|b| *b == b'\n').count() + 1;
    let col = before
        .rsplit_once('\n')
        .map(|(_, tail)| tail.len())
        .unwrap_or(before.len());
    (line, col)
}

fn collect_line_tokens(code: &str, language: &str) -> PyResult<Vec<LineToken>> {
    let mut output = Vec::new();
    for token in collect_tokens(code, language)? {
        push_line_token_segments(code, &mut output, token);
    }
    Ok(output)
}

fn push_line_token_segments(code: &str, output: &mut Vec<LineToken>, token: Token) {
    let start = token.start.min(code.len());
    let end = token.end.min(code.len());
    if start >= end {
        return;
    }

    let mut segment_start = start;
    while segment_start < end {
        let segment_end = code[segment_start..end]
            .find('\n')
            .map(|offset| segment_start + offset)
            .unwrap_or(end);
        let (line, start_col) = byte_to_line_and_col(code, segment_start);
        let (_, end_col) = byte_to_line_and_col(code, segment_end);
        if end_col > start_col {
            output.push(LineToken {
                line,
                start: start_col,
                end: end_col,
                kind: token.kind.clone(),
                raw_kind: token.raw_kind.clone(),
            });
        }
        segment_start = segment_end.saturating_add(1);
    }
}

fn collect_symbols(code: &str, language: &str) -> PyResult<Vec<Symbol>> {
    let tree = parse_tree(code, language)?;
    let mut cursor = tree.walk();
    let mut stack = vec![tree.root_node()];
    let mut symbols = Vec::new();

    while let Some(node) = stack.pop() {
        if let Some(kind) = symbol_kind(node.kind()) {
            let name = named_child_text(code, node).unwrap_or_else(|| node.kind().to_string());
            let (line, _) = byte_to_line_and_col(code, node.start_byte());
            symbols.push(Symbol {
                name,
                kind: kind.to_string(),
                start: node.start_byte(),
                end: node.end_byte(),
                line,
            });
        }
        for child in node.children(&mut cursor) {
            stack.push(child);
        }
    }

    symbols.sort_by_key(|symbol| (symbol.start, symbol.end));
    Ok(symbols)
}

fn symbol_kind(kind: &str) -> Option<&'static str> {
    match kind {
        "function_definition" | "function_declaration" | "function_item" => Some("function"),
        "method_definition" => Some("method"),
        "class_definition" | "class_declaration" => Some("class"),
        "struct_item" => Some("struct"),
        "enum_item" => Some("enum"),
        "trait_item" => Some("trait"),
        "impl_item" => Some("impl"),
        "interface_declaration" => Some("interface"),
        "module" => Some("module"),
        "decorator" | "attribute_item" => Some("decorator"),
        "property_definition" => Some("property"),
        "variable_declaration" | "variable_definition" | "shorthand_property_identifier" => Some("variable"),
        "field_declaration" | "field_definition" => Some("field"),
        "type_definition" | "type_declaration" => Some("type"),
        "enum_variant" => Some("enum_variant"),
        "import_statement" | "import_declaration" | "import_clause" => Some("import"),
        _ => None,
    }
}

fn named_child_text(code: &str, node: Node) -> Option<String> {
    for index in 0..node.named_child_count() {
        let child = node.named_child(index as u32)?;
        if matches!(
            child.kind(),
            "identifier" | "type_identifier" | "property_identifier"
        ) {
            return child.utf8_text(code.as_bytes()).ok().map(str::to_string);
        }
    }
    None
}

fn escape_html(text: &str) -> String {
    let mut output = String::with_capacity(text.len());
    for char_ in text.chars() {
        match char_ {
            '&' => output.push_str("&amp;"),
            '<' => output.push_str("&lt;"),
            '>' => output.push_str("&gt;"),
            '"' => output.push_str("&quot;"),
            '\'' => output.push_str("&#39;"),
            _ => output.push(char_),
        }
    }
    output
}

fn inline_markdown_to_html(text: &str) -> String {
    let escaped = escape_html(text);
    let mut output = String::with_capacity(escaped.len());
    let chars: Vec<char> = escaped.chars().collect();
    let mut index = 0;

    while index < chars.len() {
        if chars[index] == '`' {
            if let Some(end) = chars[index + 1..].iter().position(|char_| *char_ == '`') {
                let content: String = chars[index + 1..index + 1 + end].iter().collect();
                output.push_str("<span style='color:#DCDCAA;'>");
                output.push_str(&content);
                output.push_str("</span>");
                index += end + 2;
                continue;
            }
        }
        if chars[index] == '*' && index + 1 < chars.len() && chars[index + 1] == '*' {
            if let Some(end) = chars[index + 2..]
                .windows(2)
                .position(|window| window[0] == '*' && window[1] == '*')
            {
                let content: String = chars[index + 2..index + 2 + end].iter().collect();
                output.push_str("<b>");
                output.push_str(&content);
                output.push_str("</b>");
                index += end + 4;
                continue;
            }
        }
        output.push(chars[index]);
        index += 1;
    }

    output
}

fn markdown_to_rich_text(markdown: &str) -> String {
    let mut output = String::new();
    let mut in_code = false;
    let mut code_buffer = String::new();

    for raw_line in markdown.lines() {
        let line = raw_line.trim_end();
        if line.trim_start().starts_with("```") {
            if in_code {
                output.push_str("<pre style='margin:0; color:#DCDCAA;'>");
                output.push_str(&escape_html(code_buffer.trim_end()));
                output.push_str("</pre>");
                code_buffer.clear();
                in_code = false;
            } else {
                in_code = true;
            }
            continue;
        }

        if in_code {
            code_buffer.push_str(line);
            code_buffer.push('\n');
            continue;
        }

        let trimmed = line.trim_start();
        if let Some(title) = trimmed.strip_prefix("### ") {
            output.push_str("<span style='color:#E5C07B; font-weight:600;'>");
            output.push_str(&inline_markdown_to_html(title));
            output.push_str("</span><br>");
        } else if let Some(title) = trimmed.strip_prefix("## ") {
            output.push_str("<span style='color:#E5C07B; font-weight:600;'>");
            output.push_str(&inline_markdown_to_html(title));
            output.push_str("</span><br>");
        } else if let Some(title) = trimmed.strip_prefix("# ") {
            output.push_str("<span style='color:#E5C07B; font-weight:600;'>");
            output.push_str(&inline_markdown_to_html(title));
            output.push_str("</span><br>");
        } else if let Some(item) = trimmed.strip_prefix("- ") {
            output.push_str("<span style='color:#9CA3AF;'>•</span> ");
            output.push_str(&inline_markdown_to_html(item));
            output.push_str("<br>");
        } else if trimmed.is_empty() {
            output.push_str("<br>");
        } else {
            output.push_str(&inline_markdown_to_html(line));
            output.push_str("<br>");
        }
    }

    if in_code && !code_buffer.is_empty() {
        output.push_str("<pre style='margin:0; color:#DCDCAA;'>");
        output.push_str(&escape_html(code_buffer.trim_end()));
        output.push_str("</pre>");
    }

    output.trim_end_matches("<br>").to_string()
}

fn build_hover_document(
    signature: &str,
    documentation: &str,
    description: &str,
    language: &str,
) -> HoverDocument {
    let mut sections = Vec::new();
    if !signature.trim().is_empty() {
        sections.push(HoverSection {
            kind: "signature".to_string(),
            text: signature.trim().to_string(),
            html: format!(
                "<pre style='margin:0; color:#DCDCAA;'>{}</pre>",
                escape_html(signature.trim())
            ),
        });
    }
    if !documentation.trim().is_empty() {
        sections.push(HoverSection {
            kind: "documentation".to_string(),
            text: documentation.trim().to_string(),
            html: markdown_to_rich_text(documentation.trim()),
        });
    }
    if sections.is_empty() && !description.trim().is_empty() {
        sections.push(HoverSection {
            kind: "description".to_string(),
            text: description.trim().to_string(),
            html: markdown_to_rich_text(description.trim()),
        });
    }

    let body_html = sections
        .iter()
        .map(|section| section.html.as_str())
        .collect::<Vec<_>>()
        .join("<br><br>");

    HoverDocument {
        language: normalize_language(language),
        body_html,
        sections,
    }
}

#[pyfunction]
#[pyo3(signature = (code, language="python"))]
fn parse_code(code: String, language: &str) -> PyResult<Vec<(usize, usize, String)>> {
    Ok(collect_tokens(&code, language)?
        .into_iter()
        .map(|token| (token.start, token.end, token.kind))
        .collect())
}

#[pyfunction]
#[pyo3(signature = (code, language="python"))]
fn parse_code_json(code: String, language: &str) -> PyResult<String> {
    serde_json::to_string(&collect_tokens(&code, language)?)
        .map_err(|err| PyValueError::new_err(err.to_string()))
}

#[pyfunction]
#[pyo3(signature = (code, language="python"))]
fn highlight(code: String, language: &str) -> PyResult<String> {
    serde_json::to_string(&collect_line_tokens(&code, language)?)
        .map_err(|err| PyValueError::new_err(err.to_string()))
}

#[pyfunction]
#[pyo3(signature = (code, _changed_range=None, language="python"))]
fn highlight_incremental(
    code: String,
    _changed_range: Option<(usize, usize)>,
    language: &str,
) -> PyResult<Vec<(usize, usize, String)>> {
    parse_code(code, language)
}

#[pyfunction]
#[pyo3(signature = (code, language="python"))]
fn document_symbols(code: String, language: &str) -> PyResult<String> {
    serde_json::to_string(&collect_symbols(&code, language)?)
        .map_err(|err| PyValueError::new_err(err.to_string()))
}

#[pyfunction]
#[pyo3(signature = (signature="", documentation="", description="", language="text"))]
fn format_hover(
    signature: &str,
    documentation: &str,
    description: &str,
    language: &str,
) -> PyResult<String> {
    serde_json::to_string(&build_hover_document(
        signature,
        documentation,
        description,
        language,
    ))
    .map_err(|err| PyValueError::new_err(err.to_string()))
}

#[pyfunction]
fn supported_languages() -> Vec<&'static str> {
    vec![
        "python",
        "rust",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "html",
        "css",
    ]
}

#[pymodule]
fn ferrite(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(parse_code, m)?)?;
    m.add_function(wrap_pyfunction!(parse_code_json, m)?)?;
    m.add_function(wrap_pyfunction!(highlight, m)?)?;
    m.add_function(wrap_pyfunction!(highlight_incremental, m)?)?;
    m.add_function(wrap_pyfunction!(document_symbols, m)?)?;
    m.add_function(wrap_pyfunction!(format_hover, m)?)?;
    m.add_function(wrap_pyfunction!(supported_languages, m)?)?;
    Ok(())
}
