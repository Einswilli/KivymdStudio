import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0


Item{

    property string src
    property string name:'None'
    property int rect_width
    property int rect_height
    property color text_color
    property color back

    Rectangle{
        // x:230+380+190
        // y:weltext.height+90
        width:rect_width
        height:rect_height
        color:back
        border.color:bordercolor
        border.width:1

        Image{
            id:img
            width:parent.width-10
            height:parent.width-50
            y:4
            anchors.horizontalCenter: parent.horizontalCenter
            source:src
        }

        Text{
            text:name
            color:text_color
            font.pixelSize:14
            y:img.height+15
            anchors.horizontalCenter: parent.horizontalCenter
        }

    }
}