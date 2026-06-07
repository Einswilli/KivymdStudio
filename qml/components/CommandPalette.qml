import QtQuick 2.15
import QtQuick.Controls 2.15

/*
 * CommandPalette — Fuzzy-search command palette (Ctrl+Shift+P).
 *
 * Bound to CommandVM.search(query) for filtered results.
 * Executes CommandVM.execute(commandId) on selection.
 */

Popup {
    id: root

    property string filterText: ""
    property var theme: DesignTokens.darkTheme
    property var commands: []
    property var actions: []

    signal commandSelected(string commandId)
    signal actionSelected(string actionId)

    width: 500
    height: Math.min(420, listView.contentHeight + inputField.height + 24)
    x: (parent ? parent.width - width : 0) / 2
    y: 80
    padding: 8
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: root.theme.panel || "#252526"
        border.color: root.theme.border || "#3E3E42"
        border.width: 1
        radius: 8
    }

    onOpened: {
        inputField.text = ""
        inputField.forceActiveFocus()
        _search()
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // Search input
        TextField {
            id: inputField
            width: parent.width
            height: 36
            placeholderText: "Type a command or action..."
            placeholderTextColor: root.theme.textDim || "#666"
            color: root.theme.text || "#D4D4D4"
            font.pointSize: 13
            background: Rectangle {
                color: root.theme.inputBg || "#3C3C3C"
                border.color: root.theme.accent || "#007ACC"
                border.width: 1
                radius: 4
            }
            onTextChanged: _search()
            Keys.onDownPressed: {
                if (listView.count > 0) {
                    listView.currentIndex = 0
                    listView.forceActiveFocus()
                }
            }
            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (listView.count > 0) {
                        _execute(listView.currentIndex)
                    }
                }
                if (event.key === Qt.Key_Escape) {
                    root.close()
                }
            }
        }

        // Results list
        ListView {
            id: listView
            width: parent.width
            height: Math.min(count * 40, 300)
            clip: true
            model: root._searchResults(inputField.text)
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationWraps: true

            delegate: Rectangle {
                width: listView.width
                height: 46
                color: listView.currentIndex === index ? (root.theme.hover || "#094771") : "transparent"
                radius: 4

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Category icon/letter
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.kind === "action" ? (root.theme.accent || "#3B82F6") :
                               modelData.category === "File" ? "#C678DD" :
                               modelData.category === "Edit" ? "#61AFEF" :
                               modelData.category === "View" ? "#98C379" :
                               modelData.category === "Editor" ? "#E5C07B" :
                               modelData.category === "AI" ? "#E06C75" :
                               modelData.category === "Preferences" ? (root.theme.info || "#56B6C2") : (root.theme.textDim || "#888")
                        Text {
                            anchors.centerIn: parent
                            text: modelData.kind === "action" ? "A" : String(modelData.category || "?").charAt(0)
                            color: root.theme.textStrong || "white"
                            font.bold: true
                            font.pointSize: 12
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: listView.width - 222
                        spacing: 2

                        Text {
                            width: parent.width
                            text: modelData.title
                            color: modelData.safeToRun === false ? (root.theme.error || "#EF4444") : (root.theme.text || "#D4D4D4")
                            font.pointSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.kind === "action"
                                  ? ((modelData.requiresPermission ? "Requires permission · " : "") + (modelData.exposable ? "Agent-exposable" : "Local only"))
                                  : (modelData.category || "Command")
                            color: modelData.requiresPermission ? (root.theme.warning || "#F59E0B") : (root.theme.textDim || "#888")
                            font.pointSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Item { width: 1; height: 1 }

                    Text {
                        text: modelData.kind === "action" ? (modelData.source || "action") : modelData.keybinding
                        color: root.theme.textDim || "#888"
                        font.pointSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: _execute(index)
                }
            }

            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    _execute(listView.currentIndex)
                }
                if (event.key === Qt.Key_Escape) {
                    root.close()
                }
            }
        }
    }

    function _search() {
        listView.model = root._searchResults(inputField.text)
        listView.currentIndex = 0
    }

    function _searchResults(query) {
        var q = String(query || "").toLowerCase()
        var results = []
        var commandItems = root.commands && root.commands.length !== undefined
                           ? root.commands
                           : (CommandVM ? CommandVM.commands : [])
        for (var c = 0; commandItems && c < commandItems.length; c++) {
            var command = commandItems[c] || ({})
            var commandHaystack = String(command.id || "") + " " + String(command.title || "") + " " + String(command.category || "")
            if (q.length === 0 || commandHaystack.toLowerCase().indexOf(q) >= 0) {
                results.push({
                    "kind": "command",
                    "id": command.id || "",
                    "title": command.title || command.id || "",
                    "category": command.category || "Command",
                    "keybinding": command.keybinding || "",
                    "source": "command"
                })
            }
        }
        var actionItems = root.actions && root.actions.length !== undefined
                          ? root.actions
                          : (typeof ActionVM !== "undefined" && ActionVM ? ActionVM.actions : [])
        for (var a = 0; actionItems && a < actionItems.length; a++) {
            var action = actionItems[a] || ({})
            if (action.requiresPayload)
                continue
            var actionHaystack = String(action.id || "") + " " + String(action.title || "") + " " + String(action.category || "") + " " + String(action.description || "")
            if (q.length === 0 || actionHaystack.toLowerCase().indexOf(q) >= 0) {
                results.push({
                    "kind": "action",
                    "id": action.id || "",
                    "title": action.title || action.id || "",
                    "category": action.category || "Action",
                    "keybinding": "",
                    "source": action.source || "action",
                    "requiresPermission": action.requiresPermission || false,
                    "safeToRun": action.safeToRun !== false,
                    "exposable": action.exposable !== false
                })
            }
        }
        results.sort(function(left, right) {
            var leftKey = String(left.category || "") + "/" + String(left.title || "")
            var rightKey = String(right.category || "") + "/" + String(right.title || "")
            return leftKey.localeCompare(rightKey)
        })
        return results.slice(0, 50)
    }

    function _execute(index) {
        if (index >= 0 && index < listView.count) {
            var cmd = listView.model[index]
            if (cmd.kind === "action")
                root.actionSelected(cmd.id)
            else
                root.commandSelected(cmd.id)
            root.close()
        }
    }
}
