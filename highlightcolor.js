// import hljs from '. highlight.js/lib/core';
// import python from '.highlight.js/lib/languages/python';
const hljs = require('highlight.js/lib/core');
const python = require('highlight.js/lib/languages/python');

var text = 'def load():';

function colorify(text) {
    try {
        hljs.registerLanguage('python', python);
        console.log(hljs.highlight(text, { language: "python" }))
        return hljs.highlight(text, { language: "python" });

    } catch (error) {
        console.log(error)
    }
}