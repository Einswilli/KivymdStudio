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
            terminal.append("<ul><li><span style='color:teal'><b>"+backend.terminal()+' '+"</b><span/>"+root.cmd+"</li></ul>")
            terminal.append(output);
        }
    }

    signal toutput(string out)

    onToutput:{
        terminal.append(out);
        console.log(out)
    }

    
    Component.onCompleted: {
        // commandManager.commandOutput.connect(root.toutput)
    }

    function scrollToEnd() {
        scrollView.contentItem.contentY = terminal.height - scrollView.height;
    }

    Column{
        anchors.fill: parent
        spacing: 10

        ScrollView{
            id:scrollView
            height: parent.parent.height-inputField.height-10
            width: parent.width

            TextArea {
                id: terminal
                anchors.fill: parent
                readOnly: true
                font.family: "Courier New"
                textFormat: TextEdit.RichText
                font.pointSize: 11
                text: "<span style='color:grey'>Thanks for using KivyMDStudio...<span/><br>"
                color:'white'
                selectByMouse: true
                selectionColor: 'teal'
            }
        }

        Row{
            width: parent.width
            spacing: 10

            Rectangle{
                height: 30
                width: childrenRect.width+10
                color:'transparent'

                Text{
                    x:10
                    text:backend.terminal()
                    font.bold:true
                    color:'teal'
                    font.pointSize:14
                    anchors.verticalCenter:parent.verticalCenter
                }
            }

            Rectangle{
                height: 30
                width: parent.width*.6
                color:'transparent'

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
                    font.pointSize:12
                    cursorDelegate: Rectangle{
                        height: cursorRectangle.height
                        width:7
                    }
                    onAccepted: {
                        var command = inputField.text.trim();
                        root.cmd=inputField.text;
                        if (command !== "") {
                            // var result = 
                            CommandManager.execute_command(command);
                            root.scrollToEnd()
                            // terminal.append(result);
                        }
                        inputField.text = "";
                    }
                }
            }
        }
    }
}