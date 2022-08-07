import QtQuick 2.15

ListModel {
    id: completionItems
    property var words:[
        'print', 'input', 'abs', 'bin', 'callable', 'delattr', 'all', 'any', 'ascii',
        'chr', 'dir', 'bin', 'classmethod', 'compile', 'copyright', 'credits', 'divmod',
        'enumerate', 'eval', 'exec', 'exit', 'filter', 'format', 'getattr',
        'hasattr', 'hash', 'help', 'hex', 'id', 'isinstance', 'issubclass', 'iter', 'len',
        'license', 'map', 'max', 'memoryview', 'min', 'next', 'object', 'oct', 'open', 'ord',
        'pow', 'property', 'quit', 'repr', 'reversed', 'round', 'setattr', 'slice',
        'sorted', 'staticmethod', 'sum', 'super', 'vars', 'zip', 'capitalize', 'casefold',
        'center', 'count', 'encode', 'endswith', 'expandtabs', 'find', 'format', 'format_map',
        'index', 'isalnum', 'isalpha', 'isdecimal', 'isdigit', 'isidentifier', 'islower', 'isnumeric',
        'isprintable', 'isspace', 'istitle', 'isupper', 'join', 'ljust', 'lower', 'lstrip', 'maketrans',
        'partition', 'replace', 'rfind', 'rindex', 'rjust', 'rpartition', 'rsplit', 'rstrip', 'split',
        'splitlines', 'startswith', 'strip', 'swapcase', 'title', 'translate', 'upper', 'zfill',
        'dict', 'str', 'int', 'float', 'bool', 'list', 'type', 'bytearray', 'bytes', 'complex',
        'set', 'tuple', 'function', 'frozenset', 'range', 'fichier-bin', 'fichier-txt',
        'def', 'class', 'in', 'is', 'self', 'not', 'and', 'True', 'False', 'None','nonlocal', 'del', 
        'global', 'globals', 'locals',"import", 'as', "try", "except", 'for', "while", 'if', 'return',
        'raise', 'break', 'pass', 'continue', 'with', 'from', 'assert', 'elif','Finally', 'yield', 'lambda'
        ]
    
    
    Component.onCompleted: {
        load()
    }
    function filter(name){
        var l=[]
        for(let w of completionItems.words){
            var d={}
            if(w.substr(0,name.length)===name){
                d['name']=w
                l.push(d)
            }
        }
        //console.log(l)
        // completionItems.append(l)
        return l
    }
    function load(){
        completionItems.clear()
        //var d={} //Object.assign({}, ...words.map((x) => ({['name']: x})));
        var l=[]
        for(let w of completionItems.words){
            var d={}
            d['name']=w
            l.push(d)
        }
        //console.log(l)
        completionItems.append(l)
    }
    
    // ListElement { name: "apple" }
    // ListElement { name: "apricot" }
    // ListElement { name: "banana" }
    // ListElement { name: "orange" }
    // ListElement { name: "kiwi" }
}
