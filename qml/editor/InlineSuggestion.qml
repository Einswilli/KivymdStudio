import QtQuick 2.15

/*
 * InlineSuggestion — Ghost text overlay for AI code completions.
 *
 * Displays semi-transparent text after the cursor position.
 * Bound to EditorDocument.aiSuggestion.
 */

Item {
    id: root

    property var    target: null
    property string suggestionText: ""
    property color  ghostColor: "#808080"
    property real   ghostOpacity: 0.45

    visible: root.suggestionText.length > 0 && root.target !== null

    Text {
        id: ghost

        x: root.target ? root.target.cursorRectangle.x + root.target.cursorRectangle.width : 0
        y: root.target ? root.target.cursorRectangle.y : 0
        width: contentWidth
        height: contentHeight

        text: root.suggestionText
        color: root.ghostColor
        opacity: root.ghostOpacity
        font: root.target ? root.target.font : Qt.font({ family: "Menlo", pointSize: 12 })
    }
}
