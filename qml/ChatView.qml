import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.0

/*
 * ChatView — AI Chat panel with context awareness.
 *
 * Bound to ChatVM:
 *   ChatVM.sendMessage(text)
 *   ChatVM.messages       → message list
 *   ChatVM.isStreaming     → loading indicator
 *   ChatVM.contextPreview  → shows current file context
 *
 * AI Actions (right-click or toolbar):
 *   ChatVM.explainCode(code, language)
 *   ChatVM.refactorCode(code, language)
 *   ChatVM.generateTests(code, language)
 */

Item {
    id: root
    anchors.fill: parent
    clip: true

    property string currentCode: ""
    property string currentLanguage: "python"

    // ── Layout ───────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: "#2D2D30"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: "Ember AI"
                    color: "#FFFFFF"
                    font.bold: true
                    font.pointSize: 12
                    Layout.fillWidth: true
                }

                // Context indicator
                Rectangle {
                    visible: ChatVM ? ChatVM.contextPreview.length > 0 : false
                    Layout.preferredWidth: ctxLabel.implicitWidth + 16
                    Layout.preferredHeight: 24
                    radius: 4
                    color: "#3A3D41"

                    Text {
                        id: ctxLabel
                        anchors.centerIn: parent
                        text: "Context: " + (ChatVM ? ChatVM.contextPreview.substring(0, 30) : "")
                        color: "#888"
                        font.pointSize: 9
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            var code = currentCode || ""
                            ChatVM.setContext(code)
                        }
                    }
                }

                // AI Action buttons
                ToolButton {
                    text: "Explain"
                    onClicked: {
                        ChatVM.explainCode(root.currentCode, root.currentLanguage)
                    }
                }
                ToolButton {
                    text: "Refactor"
                    onClicked: {
                        ChatVM.refactorCode(root.currentCode, root.currentLanguage)
                    }
                }
                ToolButton {
                    text: "Tests"
                    onClicked: {
                        ChatVM.generateTests(root.currentCode, root.currentLanguage)
                    }
                }

                // Clear
                ToolButton {
                    text: "Clear"
                    onClicked: { ChatVM.clearMessages() }
                }
            }
        }

        // Message list
        ListView {
            id: messageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            model: ChatVM ? ChatVM.messages : []

            delegate: Rectangle {
                width: messageList.width - 16
                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                height: msgContent.implicitHeight + 20
                color: modelData.role === "user" ? "#2A2D2E" : "transparent"
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    Text {
                        text: modelData.role === "user" ? "You" : "AI"
                        color: modelData.role === "user" ? "#61AFEF" : "#98C379"
                        font.bold: true
                        font.pointSize: 10
                    }

                    Text {
                        id: msgContent
                        width: parent.width
                        text: modelData.content
                        color: "#D4D4D4"
                        font.pointSize: 11
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                    }
                }
            }

            // Auto-scroll
            onCountChanged: {
                if (messageList.count > 0) {
                    messageList.positionViewAtEnd()
                }
            }

            ScrollBar.vertical: ScrollBar {
                width: 8
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: "#424242"
                }
            }
        }

        // Streaming indicator
        Rectangle {
            visible: ChatVM ? ChatVM.isStreaming : false
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#1E1E1E"

            Row {
                anchors.centerIn: parent
                spacing: 8

                BusyIndicator {
                    running: true
                    width: 16
                    height: 16
                }
                Text {
                    text: "AI is thinking..."
                    color: "#888"
                    font.pointSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Input area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: "#252526"
            border.color: "#3E3E42"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                TextArea {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    placeholderText: "Ask Ember AI..."
                    placeholderTextColor: "#666"
                    color: "#D4D4D4"
                    font.pointSize: 11
                    wrapMode: TextArea.Wrap
                    background: Rectangle { color: "transparent" }

                    Keys.onPressed: {
                        if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                            event.accepted = true
                            if (inputField.text.trim().length > 0) {
                                ChatVM.sendMessage(inputField.text)
                                inputField.text = ""
                            }
                        }
                    }
                }

                Button {
                    text: "Send"
                    enabled: inputField.text.trim().length > 0
                    onClicked: {
                        ChatVM.sendMessage(inputField.text)
                        inputField.text = ""
                    }
                }
            }
        }
    }
}
