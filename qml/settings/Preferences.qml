import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill:parent

    Rectangle{
        anchors.fill:parent
        color:'transparent'

        Row{
            anchors.fill:parent
            anchors.margins:10
            spacing:10

            //RIGHT PANEL
            Rectangle{
                height:parent.height
                width:parent.width*.25
                color:'red'
            }

            //LEFT PANEL
            Rectangle{
                height:parent.height
                width:(parent.width*.75)-10
                color:'blue'
            }
        }
    }
}