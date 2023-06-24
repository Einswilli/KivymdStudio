import QtQuick 2.0

Item{
    id:root
    property string color:'#CCCCCC'
    property int _size:14
    property string text:'\uF16C'
    property bool bold:false
    

    Rectangle{
        height: childrenRect.height
        width: childrenRect.width
        anchors.centerIn: parent
        color:'transparent'

        Text{
            FontLoader { id: uifont; source: "../assets/fonts/mdicons.ttf" }
            font.family: uifont.name
            text:root.text
            color:root.color
            font.pointSize:root._size
            font.bold:root.bold
        }
    }
}