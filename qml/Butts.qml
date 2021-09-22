import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{

    property color back_color
    property string butt_text: 'ctrl'
    property color text_color

    Rectangle{
        width:text.width+15
        height:text.height+10
        color:back_color
        radius:12
        border.width:1
        border.color:'#464647'

        Text{
            id:text
            text:butt_text
            font.pixelSize:15
            font.bold:true
            color:text_color
            anchors.centerIn: parent
        }
    }
}