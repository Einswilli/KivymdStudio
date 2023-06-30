import QtQuick 2.2
import QtQuick.Layouts 1.2
import QtQuick.Controls 2.4
import QtQuick.Controls.Styles 1.4


Item{
    id:root
    property color backcolor:"#1E2326"
    property color bordercolor:"#121517"
    property int h:40
    property color plhc:"#0C2C41"
    property int fsize:12
    property int w:200
    property int bw:0
    property color bc:'#11101d'
    property string plhtext
    property bool ispass:false
    property alias txt:field.text
    property int rad:field.width/2
    property var valid:RegExpValidator{
        regExp: /^([a-zA-Z0-9_@.éè \-]+)$/
    }
    //anchors.horizontalCenter: parent.horizontalCenter


    TextField {
        id:field
        placeholderTextColor: plhc
        palette.text: plhc
        font.pointSize: fsize
        width:w
        height:h
        color:plhc
        leftPadding:20
        placeholderText:plhtext
        echoMode:ispass==true?TextInput.Password:TextInput.Normal
        //font.bold:ispass
        passwordCharacter: '·'
        passwordMaskDelay: 2
        validator:valid
        //font.family: config.font
        background: Rectangle {
            color: backcolor
            opacity: 0.7
            radius: rad
            width: parent.width
            height: parent.height
            border.width: bw
            border.color: bc
            anchors.fill: parent
        }
        wrapMode:Text.WordWrap
    }
}
