import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill:parent

    property string helper:'Helper text'
    property alias selected: check.checked

    Rectangle{
        // height:50
        // width:parent.width
        anchors.fill:parent
        color:'transparent'

        Row{
            anchors.fill:parent
            spacing:20

            //CHECKBOX
            Rectangle{
                width:parent.width*.25-10
                height:parent.height
                color:'transparent'

                //CHECKBOX
                CheckBox{
                    id:check
                    height: 20
                    width: (parent.width)-25
                    checked: true
                    anchors.verticalCenter:parent.verticalCenter
                    indicator: Row{
                        height:parent.height
                        spacing: 8
                        width:(parent.width/3)-5
                        Rectangle{
                            height: 25
                            width: 25
                            radius:5
                            color:'#2E2F30'
                            anchors.verticalCenter:parent.verticalCenter
                            Image{
                                height: 20
                                width: 20
                                source: '../../assets/icons/folder-app.svg'
                                anchors.centerIn:parent
                                visible:check.checked
                            }
                        }
                        Text{
                            text:!check.checked?'NO':'YES'
                            font.pointSize:12
                            color:'#DDDDDD'
                            anchors.verticalCenter:parent.verticalCenter
                        }
                    }
                }
            }

            //HELPER MESSAGE
            Rectangle{
                width:parent.width*.25-10
                height:parent.height
                color:'transparent'
                Text{
                    text:helper
                    // font.bold:true
                    font.pointSize:10
                    color:'#AAAAAA'
                    wrapMode:Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:parent.left
                    anchors.margins:10
                }
            }
        }
    }
}