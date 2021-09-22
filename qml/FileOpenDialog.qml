import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    
    property color theme_color
    property color border_color
    property string message:'Create new file'
    
    signal Okay(string filename)
    onOkay:return filename

    Rectangle{
        width:220
        height:150
        color:theme_color
        border.width:1
        border.color:border_color
        Text{
            x:15
            text:message
            color:'#123863'
            font.pixelSize:15
            anchors.horizontalCenter: parent.horizontalCenter
        }

        TextField{
            background: Rectangle{
                radius:12
                color:'#19191A'
            }
            y:67
            width:200
            height:40
            placeholderText: 'filename'
            placeholderTextColor: '#838485'
            bottomPadding: 3
            font.pixelSize: 14
            leftPadding: 15
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Button{
            id:but
            flat: true
            width:70
            height:35
            y:120
            x:140
        }
        Component.onCompleted:{
            but.clicked.connect(Okay)
        }

    }
}