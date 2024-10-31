import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
// import PyQt

Item{
    id:root
    anchors.fill:parent

    property string cmd:''
    

    // Création d'une instance de la classe CommandManager
    
    Connections {
        target: CommandManager
        enabled: true
        ignoreUnknownSignals: false
        function onCommandOutput(output) {
            // terminal.append("<ul><li><span style='color:teal'><b>"+backend.terminal()+' '+"</b><span/>"+root.cmd+"</li></ul>")
            terminal.append(output);
            root.scrollToEnd()
        }

        // INPUT REQUIRED
        function onInputRequired(input) {
            console.log('\n\n\n input: '+input)
        }

        // OUTPUT ENDED
        function onOutputEnded() {
            inputRow.visible = true
            // inputField.focus = true
        }
    }

    signal toutput(string out)

    onToutput:{
        terminal.append(out);
        root.scrollToEnd()
        console.log(out)
    }

    
    Component.onCompleted: {
        // commandManager.commandOutput.connect(root.toutput)
    }

    function scrollToEnd() {
        scrollView.contentItem.contentY = terminal.height - scrollView.height;
    }

    ScrollView{
        id:scrollView
        anchors.fill: parent
        // spacing: 10

        Column{
            height: parent.parent.height-inputField.height-10
            width: parent.width
            spacing:2

            TextArea {
                id: terminal
                // anchors.fill: parent
                Layout.fillHeight: true
                Layout.fillWidth: true
                readOnly: true
                font.family: "Courier New"
                textFormat: TextEdit.RichText
                font.pointSize: 9
                text: "<span style='color:grey'>Thanks for using KivyMDStudio...<span/><br>"
                color:'white'
                selectByMouse: true
                selectionColor: 'teal'
                
                // MOUSE AREA
                MouseArea{
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    enabled: false
                }
            }

            // ROW INPUT
            Row{
                id:inputRow
                width: parent.width
                spacing: 5

                Rectangle{
                    id:promptbox
                    height: childrenRect.height
                    width: childrenRect.width+10
                    color:'transparent'
                    anchors.verticalCenter:parent.verticalCenter

                    Text{
                        x:10
                        text:CommandManager.get_prompt()
                        font.bold:true
                        // color:'teal'
                        font.pointSize:9
                        textFormat: TextEdit.RichText
                        anchors.verticalCenter:parent.verticalCenter
                    }
                }

                Rectangle{
                    height: 25
                    width: scrollView.width - promptbox.width - 5
                    color:'transparent'
                    anchors.verticalCenter:parent.verticalCenter

                    TextField {
                        id: inputField
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            fill:parent
                        }
                        background:Rectangle{
                            anchors.fill: parent
                            color:'transparent'
                        }
                        focus:true
                        color:'white'
                        font.pointSize:10
                        // cursorDelegate: Rectangle{
                        //     height: cursorRectangle.height
                        //     width:7
                        // }

                        // ON CHANGED
                        onTextChanged: {
                            // text = CommandManager.colorize_output(text)
                        }

                        // ON ACCEPTED
                        onAccepted: {
                            var command = inputField.text.trim();
                            root.cmd=inputField.text;
                            if (command !== "") {
                                inputRow.visible = false
                                terminal.append('<br>'+CommandManager.get_prompt()+' '+command);
                                CommandManager.execute_command(command);
                                root.scrollToEnd()
                            }
                            inputField.text = "";
                        }
                    }
                }
            }
        }

    }
}