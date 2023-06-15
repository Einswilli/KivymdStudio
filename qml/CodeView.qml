import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill:parent

    property string code:''
    property alias c_heigt: ansView.contentHeight

    function verify(lst,word){
        var found=false
        for (let w of lst){
            if (w==word){
                //console.log(w)
                found=true
                break
            }
            else{
                found=false
            }
        }
        //console.log(found)
        return found
    }

    ScrollView{
        id:scrollView
        height: parent.height
        width: parent.width

        TextArea {
            id: ansView
            width:300
            readOnly: true
            font.family: "Courier New"
            textFormat: TextEdit.RichText
            font.pointSize: 9
            text: root.code
            color:'white'
            selectByMouse: true
            selectionColor: 'teal'
            property bool processing:false

            onTextChanged:{
                // if (!processing) {
                //     processing = true;
                //     let p = cursorPosition;
                    var t=getText(0, length)//.toString()
                    
                //     text=EditorManager.highlight(tx)
                //     // text=t;
                    
                //     cursorPosition = p;
                //     processing = false;
                //     //minimap.text=t
                // }

                var violets = [
                    "import", 'as', "try", "except", 'for', "while", 'if', 'return',
                    'raise', 'break', 'pass', 'continue', 'with', 'from', 'assert', 'elif',
                    'Finally', 'yield', 'lambda'
                ]
                var bleus = [
                    'def', 'class', 'in', 'is', 'self', 'not', 'and', 'True', 'False', 'None',
                    'nonlocal', 'del', 'global', 'globals', 'locals'
                ]
                var yellows = [
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
                    'splitlines', 'startswith', 'strip', 'swapcase', 'title', 'translate', 'upper', 'zfill'
                ]
                var greens = [
                    'dict', 'str', 'int', 'float', 'bool', 'list', 'type', 'bytearray', 'bytes', 'complex',
                    'set', 'tuple', 'function', 'frozenset', 'range', 'fichier-bin', 'fichier-txt'
                ]
                t.replace(/([A-Z][A-Za-z]*|[a-z][A-Za-z]*|[0-9]+|[ \t\n]|['][^']*[']|[^A-Za-z0-9\t\n ])/g,
                                    function(f){
                                        if(f.match(/&#39;#[a-zA-Z0-9]*&#39;/))
                                            return '<span style="background-color:"'+f.replace('&#39;','')+'>'+f+'</span>'
                                    })

                if (!processing) {
                    processing = true;
                    let p = cursorPosition;
                    let markUp = getText(0, length).replace(
                        /([A-Z][A-Za-z]*|[a-z][A-Za-z]*|[0-9]+|[ \t\n]|['][^']*[']|[^A-Za-z0-9\t\n ])/g,
                        function(f) {
                            // console.log("f: ", JSON.stringify(f));
                            if (f.match(/^[A-Z][A-Za-z_]*$/)) {
                                return "<span style='color:#00EBCB'>" + f + "</span>";
                            } else if (f.match(/#[^\n]*/)) {
                                return "<span style='color:#0F572D'>" + f + "</span>";
                            } else if (f.match(/^[a-z][A-Za-z]*$/))
                                var re = f.match(/^[a-z][A-Za-z]*$/)
                            if (root.verify(yellows, re)) {
                                return "<span style='color:#A39C3D'>" + f + "</span>";
                            } else if (root.verify(violets, re)) {
                                return "<span style='color:#8C0099'>" + f + "</span>";
                            } else if (root.verify(bleus, re)) {
                                return "<span style='color:#123F81'>" + f + "</span>";
                            } else if (root.verify(greens, re)) {
                                return "<span style='color:#00EBCB'>" + f + "</span>";
                            } else if (f.match(/^[0-9]+$/))
                                return "<span style='color:#5EA3B8'>" + f + "</span>";
                            else if (f.match(/([A-Za-z0-9_]*)(?==)/))
                                return "<span style='color:#ABDDD9'>" + f + "</span>";
                            else if (f.match(/^[A-Z0-9_]*$/))
                                return "<span style='color:#009FCF'>" + f + "</span>";

                            else if (f.match(/(?<=def)\w*|\w*(?=\()/))
                                return "<span style='color:#A39C3D'>" + f + "</span>";

                            else if (f.match(/^[ ]/))
                                return "&nbsp;"
                            else if (f.match(/^[\t\n]/))
                                return " &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; ";
                            // else if (f.match(/^[\s]/))
                            //     return f;
                            else if (f.match(/^[']/))
                                return "<span style='color:#9B6039'>" + f + "</span>";
                            else if (f.match(/^"""[^]*)"""$/g))
                                return "<span style='color:#9B6039'>" + f + "</span>";
                            else
                                return f;
                        }
                    );
                    text = markUp;
                    cursorPosition = p;
                    processing = false;
                }
            }
        }
    }
}