import QtQuick 2.0
import QtQuick.Controls 2.0

Item {
    id: minimap
    width: 200
    height: 150

    // Propriétés de l'éditeur principal
    property Item textEditor: null
    property real textEditorContentHeight: 0
    property real textEditorVisibleHeight: 0
    property real minimapContentHeight: 0
    property real minimapVisibleHeight: 0

    
    Component.onCompleted: {
        minimapMouseArea.drag.started.connect(function() { minimapContent.forceActiveFocus() })
        minimapMouseArea.drag.updated.connect(updatetextEditorPosition)
    }
    

    // Calcul de la hauteur de contenu et de la hauteur visible de l'éditeur principal
    function updatetextEditorHeights() {
        if (textEditor) {
            textEditorContentHeight = textEditor.contentHeight
            textEditorVisibleHeight = textEditor.height
            updateMinimap()
        }
    }

    // Mise à jour de la taille et de la position de la vue minimap
    function updateMinimap() {
        minimapVisibleHeight = height * (textEditorVisibleHeight / textEditorContentHeight)
        minimapContentHeight = height
        minimapContent.y = -(textEditor.visibleArea.y / textEditorContentHeight) * minimapContentHeight
    }

    // Mise à jour de la position de l'éditeur principal en fonction de la vue minimap
    function updatetextEditorPosition() {
        textEditor.visibleArea.y = -(minimapContent.y / minimapContentHeight) * textEditorContentHeight
    }

    // Écoute des événements de l'éditeur principal
    onTextEditorChanged: {
        if (textEditor) {
            textEditor.contentHeightChanged.connect(updatetextEditorHeights)
            textEditor.heightChanged.connect(updatetextEditorHeights)
            textEditor.visibleAreaChanged.connect(updateMinimap)
            minimapContent.mouseArea.pressed.connect(updatetextEditorPosition)
            
            console.log("EDITOR: CHANGED ")
        }
    }

    // Contenu de la minimap
    Rectangle {
        id: minimapContent
        width: minimap.width
        height: minimap.height
        color: "transparent"

        MouseArea {
            id: minimapMouseArea
            anchors.fill: parent
            drag.target: minimapContent
            drag.axis: Drag.YAxis
            drag.minimumY: 0
            drag.maximumY: minimap.height - minimapVisibleHeight
            // drag.minimumY: 0
            // drag.maximumY: minimap.height - minimapVisibleHeight
            // drag.active: minimapVisibleHeight < minimapContent.height
        }
    }

    // Vue de la minimap
    Rectangle {
        id: minimapView
        width: minimap.width
        height: minimapVisibleHeight
        color: "grey"
        opacity: 0.5
        border.width: 1
        border.color: "black"
        y: minimapContent.y
    }
}