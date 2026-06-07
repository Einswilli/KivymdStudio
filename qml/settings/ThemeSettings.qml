import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.0

/*
 * ThemeSettings — Theme configuration panel.
 * Bound to SettingsVM for live theme preview and font configuration.
 */

Item {
    id: root
    clip: true

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20

        ColumnLayout {
            width: parent.width - 40
            spacing: 20

            // Title
            Text {
                text: "Theme Settings"
                font.pointSize: 18
                font.bold: true
                color: "#FFFFFF"
                Layout.alignment: Qt.AlignLeft
            }

            // Theme Selector
            GroupBox {
                title: "Color Theme"
                Layout.fillWidth: true

                background: Rectangle {
                    color: "#2D2D30"
                    border.color: "#3E3E42"
                }

                GridLayout {
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 10
                    anchors.fill: parent

                    Repeater {
                        model: SettingsVM ? SettingsVM.availableThemes() : ["Ember Dark"]
                        delegate: Rectangle {
                            width: 140
                            height: 80
                            radius: 6
                            property string themeName: modelData
                            border.width: SettingsVM ? (SettingsVM.currentTheme === themeName ? 2 : 1) : 1
                            border.color: SettingsVM ? (SettingsVM.currentTheme === themeName ? "#007ACC" : "#3E3E42") : "#3E3E42"

                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: themeName.indexOf("Light") >= 0 ? "#F5F5F5" : "#1E1E1E"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: themeName.indexOf("Light") >= 0 ? "#FFFFFF" : "#252526"
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: themeName.replace("Ember ", "")
                                color: themeName.indexOf("Light") >= 0 ? "#333333" : "#CCCCCC"
                                font.pointSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (SettingsVM) {
                                        var colors = SettingsVM.applyTheme(themeName)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Font Settings
            GroupBox {
                title: "Font"
                Layout.fillWidth: true
                background: Rectangle {
                    color: "#2D2D30"
                    border.color: "#3E3E42"
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Text { text: "Font Family:"; color: "#CCCCCC"; Layout.preferredWidth: 100 }
                        ComboBox {
                            id: fontFamily
                            Layout.fillWidth: true
                            model: ["Menlo", "Monaco", "Fira Code", "JetBrains Mono", "Cascadia Code", "Source Code Pro", "Consolas", "Courier New"]
                            currentIndex: 0
                            onCurrentTextChanged: {
                                if (SettingsVM) SettingsVM.setFont(currentText, fontSize.value)
                            }
                            background: Rectangle { color: "#3C3C3C"; border.color: "#3E3E42" }
                        }
                    }

                    RowLayout {
                        Text { text: "Font Size:"; color: "#CCCCCC"; Layout.preferredWidth: 100 }
                        SpinBox {
                            id: fontSize
                            from: 10
                            to: 24
                            value: SettingsVM ? SettingsVM.fontSize : 12
                            onValueChanged: {
                                if (SettingsVM) SettingsVM.setFont(fontFamily.currentText, value)
                            }
                            background: Rectangle { color: "#3C3C3C"; border.color: "#3E3E42" }
                        }
                    }

                    RowLayout {
                        Text { text: "Line Spacing:"; color: "#CCCCCC"; Layout.preferredWidth: 100 }
                        SpinBox {
                            id: lineSpacing
                            from: 2
                            to: 16
                            value: SettingsVM ? SettingsVM.editorLineSpacing : 6
                            onValueChanged: {
                                if (SettingsVM) SettingsVM.setEditorLineSpacing(value)
                            }
                            background: Rectangle { color: "#3C3C3C"; border.color: "#3E3E42" }
                        }
                    }

                    RowLayout {
                        Text { text: "Tab Size:"; color: "#CCCCCC"; Layout.preferredWidth: 100 }
                        SpinBox {
                            id: tabSize
                            from: 2
                            to: 8
                            value: 4
                            background: Rectangle { color: "#3C3C3C"; border.color: "#3E3E42" }
                        }
                    }

                    CheckBox {
                        text: "Enable ligatures"
                        checked: true
                    }
                }
            }

            // Editor Preview
            GroupBox {
                title: "Preview"
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                background: Rectangle {
                    color: "#1E1E1E"
                    border.color: "#3E3E42"
                }

                TextEdit {
                    anchors.fill: parent
                    anchors.margins: 10
                    readOnly: true
                    textFormat: TextEdit.RichText
                    font: Qt.font({
                        family: fontFamily.currentText,
                        pointSize: fontSize.value
                    })
                    color: "#D4D4D4"
                    text: '<pre style="color: #D4D4D4">' +
                          '<span style="color: #C678DD">def</span> ' +
                          '<span style="color: #61AFEF">hello</span>' +
                          '<span style="color: #D4D4D4">(</span>' +
                          '<span style="color: #E06C75">name</span>' +
                          '<span style="color: #D4D4D4">):</span><br>' +
                          '&nbsp;&nbsp;&nbsp;&nbsp;' +
                          '<span style="color: #C678DD">return</span> ' +
                          '<span style="color: #98C379">f"Hello, {name}"</span>' +
                          '</pre>'
                }
            }
        }
    }
}
