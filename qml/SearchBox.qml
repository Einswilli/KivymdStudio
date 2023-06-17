import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill:parent

    property bool is_empty:true

    Column{
        anchors.fill:parent
        anchors.margins: 10
        spacing:10
        
        //SEARCH FIELD BOX
        Rectangle{
            height:45
            width:parent.width
            color:'transparent'

            TextField{
                width:parent.width//-20
                height:parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                color:'#FFFFFF'//'#AEB5BD'
                font.pointSize:13
                background: Rectangle{
                    anchors.fill: parent
                    radius:4
                    color:"#292828"
                    border.width:1
                    border.color:moyen//'#045685'
                }
                placeholderText: 'Search...'
                placeholderTextColor: '#DDDDDD'
                leftPadding: 10
                bottomPadding:3
            }
        }

        //RESULT BOX
        Rectangle{
            height:parent.height-55
            width:parent.width
            color:'transparent'

            Image{
                width:150
                height:width
                source:'../assets/icons/search_file.png'
                anchors.centerIn: parent
                visible:root.is_empty
            }

            Component{
                id:file_delegate
                Rectangle{
                    height:25
                    width:list.width
                }
            }

            ListModel{
                id:file_model
            }

            ScrollView{
                anchors.fill:parent

                ListView{
                    id:list
                    anchors.fill:parent
                    delegate:file_delegate
                    model:file_model
                    spacing:5
                }
            }
        }
    }
}