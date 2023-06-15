import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill: parent

    Column{
        anchors.fill:parent
        anchors.margins: 10
        spacing: 5

        Rectangle{
            height: root.height*.08
            width: parent.width
            color:'transparent'

            Row{
                anchors.fill:parent
                anchors.margins: 5
                spacing:10

                Rectangle{
                    height:parent.height
                    width:height
                    color:'transparent'

                    Image{
                        anchors.fill:parent
                        anchors.margins: 5
                        source:'../assets/icons/chatgpt.png'
                        fillMode:Image.PreserveAspectFit
                    }
                }

                Rectangle{
                    radius:8
                    color:'transparent'
                    height:parent.height
                    width:parent.width-height-10
                    border{
                        width:0
                        color:'#DDDDDD'
                    }

                    Text{
                        text:'Hi, welcome to KivyMDStudio'
                        color:'#FFFFFF'
                        font.pointSize:10
                    
                        anchors.centerIn: parent
                    }
                }
            }
        }

        Rectangle{
            height: root.height*.76
            width: parent.width
            color:'transparent'

            ScrollView{
                anchors.fill: parent
                clip:true
            }
        }

        Rectangle{
            height: root.height*.12
            width: parent.width
            color:'transparent'

            Row{
                anchors.fill:parent
                spacing: 10

                // INPUT FIELD
                ScrollView{
                    id:sc
                    height: parent.height
                    width: parent.width*.84
                    clip:true

                    Column{
                        id:col
                        height:childrenRect.height
                        width:childrenRect.width
                        Rectangle{
                            id:rect
                            height: sc.height
                            width: sc.width-5//*.84
                            color:'#292828'
                            radius: 8
                            // clip:true

                            TextInput{
                                id:question
                                anchors.fill:parent
                                autoScroll: true
                                color:'white'
                                font.family:'monospace'
                                selectByMouse: true
                                font.pointSize:12
                                padding :5
                                // placeholderText:'Text...'
                                //topPadding:2
                                wrapMode: Text.WordWrap
                                enabled:true
                                focus: true
                                mouseSelectionMode:TextEdit.SelectCharacters
                                // background:Rectangle{
                                //     anchors.fill: parent
                                //     color:'#292828'
                                //     radius: 8
                                // }

                                onTextChanged: {
                                    var delta=sc.height-contentHeight
                                    rect.height=Math.max(sc.height,contentHeight)
                                    // delta>0?0:Math.abs(delta)+10
                                    sc.contentItem.contentY = parent.height - sc.height;
                                    //Math.max(sc.height,Math.min(sc.height,contentHeight))
                                }
                            }
                        }
                        Rectangle{
                            height:20
                            width:parent.width
                            color:'transparent'
                        }
                    }
                    ScrollBar.vertical{
                        width: 15
                        size:parent.height/(question.contentHeight+10)
                        policy:ScrollBar.AlwaysOn
                    }
                }

                //BUTTON
                Rectangle{
                    height: parent.height
                    width: parent.width*.14
                    color:'transparent'

                    Rectangle{
                        id:send
                        anchors.fill:parent
                        anchors.margins:5
                        color:'transparent'
                        
                        Image{
                            height:25
                            width:25
                            source:'../assets/icons/send.png'
                            anchors.centerIn: parent
                        }
                    }
                }
            }
        }
    }
}
