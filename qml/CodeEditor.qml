import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
//import '../Js/highlightcolor.js' as Logic
import '../Js/prism.js' as Logic

Item{

    id:root

    Connections{
        enabled: true
        ignoreUnknownSignals: false
        target: backend

        function onColorhighlight(value){
            return value
        }
        function onFolderOpen(value){
            return JSON.stringify(value)
        }

    }

    property alias scode:editor

    readonly property real lineHeight: (editor.implicitHeight - 2 * editor.textMargin) / editor.lineCount
    readonly property alias lineCount: editor.lineCount

    function verify(lst,word ){
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

    property int edit_height
    property int edit_width
    property color flk_color
    property color compcolor
    property alias code:editor.text

    Flickable {
        id: flickb
        //anchors.fill: parent
        width:edit_width//parent.width-20 
        height: edit_height//parent.height-20
        anchors.centerIn: parent
        contentWidth: editor.paintedWidth
        contentHeight: editor.paintedHeight+300
        clip: true

        function ensureVisible(r)
        {
            if (contentX >= r.x)
                contentX = r.x;
            else if (contentX+width <= r.x+r.width)
                contentX = r.x+r.width-width;
            if (contentY >= r.y)
                contentY += r.y//-120;
            
            else if (contentY+height <= r.y+r.height)
                contentY = r.y+r.height-height;
        }

        // Rectangle{
        //     id:lines
        //     width:60
        //     height:(editor.lineCount*25)+parent.height
        //     anchors.left:parent.left
        //     color:barfonce

        //     Component{
        //         id:comp
        //         Rectangle{
        //             width:58
        //             height:25
        //             color:compcolor

        //             Text{
        //                 text:num
        //                 color:'white'
        //                 font.pixelSize:14
        //                 anchors.centerIn: parent
        //             }
        //             Rectangle{
        //                 width:parent.width
        //                 height:1
        //                 color:'black'
        //                 anchors.bottom:parent.bottom
        //             }
        //         }
        //     }

        //     ListModel{
        //         id:mod
        //         ListElement{
        //             num:1
        //         }
        //         dynamicRoles: false
        //     }

        //     ListView{
        //         y:5
        //         model:mod
        //         delegate:comp
        //         anchors.fill: parent
        //     }
        // }
        

        Column {
            // start position of line numbers depends on text margin
            y: editor.textMargin
            width: parent.width


            // add line numbers based on line count and height
            Repeater {
                id:rep
                model: editor.lineCount
                delegate: Text {
                    id: text
                    width: implicitWidth
                    height: root.lineHeight
                    color: "#898A8B"
                    font: editor.font
                    text: index + 1
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled:true

                        onClicked:{
                            
                        }
                    }
                }
            }
        }
        
        TextEdit{
            id:editor
            focus:true
            width: flickb.width
            height: (lineCount*25)+flickb.height//flickb.height
            color:'white'
            mouseSelectionMode:TextEdit.SelectCharacters
            font.pixelSize:16
            font.family:'monospace'
            selectByMouse: true
            selectionColor: '#1C98E0'
            tabStopDistance: 40
            textFormat: TextEdit.RichText
            property bool processing:false
            leftPadding :35
            topPadding:2
            wrapMode: Text.WordWrap
            selectedTextColor :'#060707'
            
            //baselineOffset :35
            

            onCursorRectangleChanged:{
                flickb.ensureVisible(cursorRectangle)
                //flickb.ensureVisible(lines)
            }
            // onCursorPositionChanged: {
            //     if(cursorRectangle.y < 10 - editor.y){//Cursor went off the front
            //         editor.y = 10 - Math.max(0, cursorRectangle.y);
            //     }else if(cursorRectangle.y > parent.height - 20 - editor.y){//Cursor went off the end
            //         editor.y = 10 - Math.max(0, cursorRectangle.y - (parent.height - 20) + cursorRectangle.height);
            //     }
            // }
            //Keys.onEnterPressed:{
                
            // }
            
            onTextChanged: {
                
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
                    'set', 'tuple', 'function', 'frozenset', 'range', 'fichier-bin', 'fichier-txt','Object',
                    'Slot'
                ]
                var oranges=[
                    '__init__','__str__','__repr__','__dict__','__hash__','__annotations__','__delatrtr__','__class__',
                    '__dir__','__doc__','__eq__','__format__','__getattribute__','__init_subclass__','__module__','__reduce__',
                    '__ne__','__new__','__reduce_ex__','__sizeof__','setattr__','__slots__'
                ]
                var kv=[
                    'MDBoxLayout',
                ]
                //const Prism = require('prismjs');
                //console.log(text)
                
                if (!processing) {
                    processing = true;
                    let p = cursorPosition;
                    let l=text.length
                    //console.log(l)
                    //for(var i in text.split('\n'))
                    // var t=backend.highlight(getText(0,length))//.split('\n'))
                    // text=t
                    //console.log(t)
                    
                    let markUp = getText(0, length).replace(
                        /([A-Z][A-Za-z]*|[a-z][A-Za-z]*|[A-Z][A-Za-z_]*|[a-z][A-Za-z_]*|[0-9]+|[ \t\n]|['][^']*[']|[^A-Za-z0-9\t\n ])/g,
                        function(f) {
                            //console.log("f: ", JSON.stringify(f));
                            if (f.match(/(?<=class\s+)\w+/)) {
                                return "<span style='color:#00EBCB'>" + f + "</span>";
                            } 
                            else if (f.match(/#/)) {
                                return "<span style='color:#0F572D'>" + f + "</span>";
                            } else if (f.match(/[A-Za-z]\w+|__\w+__/))
                                var reg = f.match(/^__\w+__/)
                                var re = f.match(/[A-Za-z_]\w+|__\w+__/)
                            if (root.verify(yellows, re)) {
                                return "<span style='color:#E2D958'>" + f + "</span>";
                            } else if (root.verify(violets, re)) {
                                return "<span style='color:#9607A3'><b>" + f + "<b/></span>";
                            } else if (root.verify(bleus, re)) {
                                return "<span style='color:#19478B'><b>" + f + "<b/></span>";
                            } else if (root.verify(greens, re)) {
                                return "<span style='color:#00EBCB'>" + f + "</span>";
                            }else if (f.match(/\b(?:init|__str__|repr|__dict__|hash|annotations|delatrtr|__class__|dir|doc|eq|format|getattribute|init_subclass|module|reduce|ne|new|reduce_ex|sizeof|setattr|slots)\b/)) {
                                return "<span style='color:#EB7200'><b>" + f + "<b/></span>";
                            }else if (f.match(/^(def\s+\w+)/))
                                return "<span style='color:#E2D958'>" + f + "</span>";
                            else if (f.match(/^[0-9]+$/))
                                return "<span style='color:#8BE2CF'>" + f + "</span>";
                            else if (f.match(/[{}[\](),]/))
                                return "<span style='color:#729DDD'>" + f + "</span>";

                            else if (f.match(/[-+%=]=?|!=|:=|\*\*?=?|\/\/?=?|<[<=>]?|>[=>]?|[&|^~]/))
                                return "<span style='color:#C2988B'>" + f + "</span>";
                            else if(f.match(/def\s[a-zA-Z_][a-zA-Z0-9_]*)/)){
                                return "<span style='color:#E2D958'>" + f + "</span>";
                            }

                            else if (f.match(f.match(/(MD)[A-Z]\w*)/))){
                                return "<span style='color:#00EBCB''>" + f + "</span>";
                            }
                            // if(f.match(/(?:__init__)/)){
                            //     return "<span style='color:#009FCF'>" + f + "</span>";
                            // }
                            else if(f.match(/\b[A-Z](?:[A-Z_]|\dx?)*\b/)){

                                return "<span style='color:#009FCF'>" + f + "</span>";
                            }
                            
                            else if (f.match(/(^[\t ]*)@\w+(?:\.\w+)*/im))
                                return "<span style='color:#00EBCB'>" + f + "</span>";

                            else if (f.match(/^[ ]/))
                                return "&nbsp;"
                            else if (f.match(/^[\t]/))
                                return u0009//'<span style="margin:0px, 0px, 0px ,40px">''<span>'//U+0009
                            else if (f.match(/\r\n|\r|\n/)){
                                console.log('retour!')
                                return '<br/>'//(U+000A)
                            }else if (f.match(/^['\|"\|'''\|"""]/))
                                return "<span style='color:#C46F37'>" + f + "</span>";
                            else if (f.match(/(?:[rub]|br|rb)?("""|''')[\s\S]*?\1/i))
                                return "<span style='color:#9B6039'>" + f + "</span>";
                            // else if (f.match(/["]/))
                            //     return "<span style='color:#9B6039'>" + f + "</span>";
                            else
                                return "<span style='color:#9CB9C2'>" + f + "</span>";
                        }
                    );
                    text = markUp;
                    cursorPosition = p;
                    processing = false;
                }
                
            }
            
        }
        Rectangle{
            y:editor.cursorRectangle.y
            color: 'transparent'//index === editor.currentLine ? "#00A2FF" : "transparent"
            height: root.lineHeight
            width: editor.width+100
            border.width:1
            border.color:bordercolor
        }
    }
    
}