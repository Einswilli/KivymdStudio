function colorify(code) {
    const Prism = require('prismjs');
    const c = Prism.highlight(code, Prism.languages.javascript, 'javascript');
    console.log(c)
    return c
}

// Returns a highlighted HTML string
// "language-python"

// const highlight = (code, language) => {
//     loadPrismLanguage(language)
//     return Prism.highlight(code, Prism.languages[language])
//    }