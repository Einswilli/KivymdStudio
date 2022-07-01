//import Felgo 3.0
import QtQuick 2.15

Item {
  id: editorRoot

  // line height and line count of text edit
  readonly property real lineHeight: (textEdit.implicitHeight - 2 * textEdit.textMargin) / textEdit.lineCount
  readonly property alias lineCount: textEdit.lineCount
  
  // ...

  Column {
    // start position of line numbers depends on text margin
    y: textEdit.textMargin
    width: parent.width

   // add line numbers based on line count and height
    Repeater {
      model: editorRoot.lineCount
      delegate: Text {
        id: text
        width: implicitWidth
        height: editorRoot.lineHeight
        color: "#666"
        font: textEdit.font
        text: index + 1
      }
    }
  }

  // ...

 TextEdit {
    id: textEdit

    property int currentLine: text.substring(0, cursorPosition).split(/\r\n|\r|\n/).length - 1
    textMargin: 30
    wrapMode: Text.WordWrap
    anchors {
      fill: parent
      topMargin: 2
      leftMargin: numbersColumnWidth + 10
    }
    selectByKeyboard: true
    selectByMouse: true
    textFormat: Qt.PlainText
    verticalAlignment: TextEdit.AlignTop
  }


  FocusScope {
    id: root
    property alias font: textEdit.font
    property alias text: textEdit.text

    Rectangle {
        color: "lightyellow"
        height: textEdit.cursorRectangle.height
        width: root.width
        visible: root.focus
        y: textEdit.cursorRectangle.y
    }

    TextEdit {
        id: textEdit
        anchors.fill: parent
        focus: true
     }
}

 // ...
}