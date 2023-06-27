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

    Column{
        anchors.fill:parent
        spacing:10

        //TEXT
        Rectangle{
            height:40
            width:parent.width
            color:'transparent'
            Text{
                text:"OpenAI Settings"
                font.bold:true
                font.pointSize:18
                color:'#AAAAAA'
                anchors.verticalCenter: parent.verticalCenter
                anchors.left:parent.left
                anchors.margins:10
            }

            //BUTTON
            Rectangle{
                height: parent.height
                width: Math.min((parent.width*.2),130)
                color:parent.color
                anchors.right:parent.right
                anchors.margins:15
                Rectangle{
                    color:'#2E2F30'
                    radius:8
                    height: parent.height-10
                    width: parent.width-30
                    border.color:'#464647'
                    anchors.centerIn: parent
                    Text{
                        text:'save'
                        color:'#EEEEEE'
                        font.pointSize:12
                        anchors.centerIn: parent
                    }
                    MouseArea{
                        anchors.fill:parent
                        hoverEnabled: true
                        onEntered: {
                            parent.color='#464647'
                        }
                        onExited: {
                            parent.color='#2E2F30'
                        }
                        onClicked: {
                            //
                        }
                    }
                }
            }
        }

        Rectangle{
            height:parent.height-50
            width:parent.width
            color:'transparent'

            ScrollView{
                anchors.fill:parent
                clip:true

                Column{
                    spacing:10
                    anchors.fill:parent
                    anchors.leftMargin:10
                    anchors.rightMargin:30
                    // anchors.horizontalCenter: parent.horizontalCenter

                    //TEXT
                    Rectangle{
                        height:20
                        width:parent.width
                        color:'transparent'
                        Text{
                            text:"OPENAI API_KEY"
                            // font.bold:true
                            font.pointSize:12
                            color:'#AAAAAA'
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:parent.left
                            anchors.margins:10
                        }
                    }

                    //API KEY
                    Rectangle{
                        height: 50
                        width:parent.parent.width
                        color:'transparent'

                        Input{
                            id:apikeyinput
                            h:parent.height
                            w:parent.width*.70
                            rad:0
                            backcolor:'#292828'
                            plhc:'#CCCCCC'
                            plhtext:'your api key'
                        }
                    }

                    //TEXT
                    Rectangle{
                        height:20
                        width:parent.width
                        color:'transparent'
                        Text{
                            text:"MODEL"
                            // font.bold:true
                            font.pointSize:12
                            color:'#AAAAAA'
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:parent.left
                            anchors.margins:10
                        }
                    }

                    //MODEL
                    Rectangle{
                        height:50
                        width:parent.parent.width
                        color:'transparent'

                        Input{
                            id:modelinput
                            h:parent.height
                            w:parent.width*.70
                            rad:0
                            backcolor:'#292828'
                            plhc:'#CCCCCC'
                            plhtext:'text-davinci-003'
                            valid:RegExpValidator{
                                regExp: /^([a-zA-Z1-9._\-]+)$/
                            }
                        }
                    }

                    //TEXT
                    Rectangle{
                        height:20
                        width:parent.width
                        color:'transparent'
                        Text{
                            text:"MAX TOKENS"
                            // font.bold:true
                            font.pointSize:12
                            color:'#AAAAAA'
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:parent.left
                            anchors.margins:10
                        }
                    }

                    //TOKEN
                    Rectangle{
                        height: 50
                        width:parent.parent.width
                        color:'transparent'

                        Input{
                            id:maxtokeninput
                            h:parent.height
                            w:parent.width*.70
                            rad:0
                            backcolor:'#292828'
                            plhc:'#CCCCCC'
                            plhtext:'2000'
                            valid:RegExpValidator{
                                regExp: /^([1-9]+)$/
                            }
                        }
                    }

                    //TEXT
                    Rectangle{
                        height:20
                        width:parent.width
                        color:'transparent'
                        Text{
                            text:"TEMPERATURE"
                            // font.bold:true
                            font.pointSize:12
                            color:'#AAAAAA'
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:parent.left
                            anchors.margins:10
                        }
                    }

                    //TEMPERATURE
                    Rectangle{
                        height:50
                        width:parent.parent.width
                        color:'transparent'

                        Input{
                            id:tempertureinput
                            h:parent.height
                            w:parent.width*.70
                            rad:0
                            backcolor:'#292828'
                            plhc:'#CCCCCC'
                            plhtext:'0.5'
                            valid:RegExpValidator{
                                regExp: /^([0-9.]+)$/
                            }
                        }
                    }

                    //TEXT
                    Rectangle{
                        height:20
                        width:parent.width
                        color:'transparent'
                        Text{
                            text:"MAX ALTERNATIVES"
                            // font.bold:true
                            font.pointSize:12
                            color:'#AAAAAA'
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left:parent.left
                            anchors.margins:10
                        }
                    }

                    //ALTERNATIVES
                    Rectangle{
                        height: 50
                        width:parent.parent.width
                        color:'transparent'

                        Input{
                            id:alternativesinput
                            h:parent.height
                            w:parent.width*.70
                            rad:0
                            backcolor:'#292828'
                            plhc:'#CCCCCC'
                            plhtext:'4'
                            valid:RegExpValidator{
                                regExp: /^([1-9]+)$/
                            }
                        }
                    }
                }
            }
        }
    }
}