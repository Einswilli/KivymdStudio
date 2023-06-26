import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
import '../'

Item{
    id:root
    anchors.fill:parent

    property bool active:false
    property string label:'My navItem'
    property string _color:'#EEEFFF'
    property string icon:'cog-outline'

    
    signal tapped()

    Rectangle{
        height:30
        width:parent.width*.75
        color:'transparent'
        anchors.centerIn: parent

        Row{
            anchors.fill:parent
            spacing:10

            Rectangle{
                height:parent.height
                width:height
                color:'transparent'
                anchors.verticalCenter: parent.verticalCenter

                TextIcon{
                    id:ico_
                    _size:17
                    text: icons[icon]
                    anchors.fill: parent
                    color:active?_color:'#AAAAAA'
                }
            }

            Text{
                id:lab
                text:label
                font.pointSize:11
                color:active?_color:'#AAAAAA'
                anchors.verticalCenter: parent.verticalCenter
            }

            MouseArea{
                anchors.fill:parent
                hoverEnabled:true

                onEntered:{
                    ico_.scale=1.1
                    lab.scale=1.1
                }

                onExited:{
                    ico_.scale=1
                    lab.scale=1
                }

                onClicked:{
                    active=true
                    root.tapped()
                }
            }
        }
    }
}