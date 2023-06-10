import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill: parent

    Connections {
        target: StackManager
        enabled: true
        ignoreUnknownSignals: false
        function onResult(value){
            questionmodel.append(JSON.parse(value))
        }
    }

    Column{
        anchors.fill:parent
        anchors.margins: 10
        spacing: 15

        Rectangle{
            height: root.height*.07
            width: parent.width
            color:'transparent'

            Row{
                anchors.fill:parent
                anchors.margins: 0
                spacing:5

                Rectangle{
                    radius:8
                    color:'transparent'
                    height:parent.height
                    width:parent.width-height-5

                    TextField{
                        id:question
                        anchors.fill:parent
                        autoScroll: true
                        color:'white'
                        font.family:'monospace'
                        selectByMouse: true
                        font.pointSize:10
                        padding :5
                        placeholderText:'search on Stackoverflow'
                        //topPadding:2
                        wrapMode: Text.WordWrap
                        enabled:true
                        focus: true
                        mouseSelectionMode:TextEdit.SelectCharacters
                        background:Rectangle{
                            anchors.fill: parent
                            color:'#292828'
                            radius: 7
                            // border{
                            //     width:1
                            //     color:'#CCCCCC'
                            // }
                        }

                        Keys.onReturnPressed:{
                            StackManager.search(text)
                            // questionmodel.append(JSON.parse(StackManager.search(text)))
                        }
                    }
                }

                Rectangle{
                    height:parent.height
                    width:height
                    color:'transparent'

                    Image{
                        anchors.fill:parent
                        anchors.margins: 10
                        source:'../assets/icons/loupe.png'
                    }
                }
            }
        }

        Rectangle{
            height: root.height*.88
            width: parent.width
            color:'transparent'

            ListModel{
                id:questionmodel
            }

            Component{
                id:questiondelegate
                Rectangle{
                    height:200
                    width:parent.width
                    color:  index % 2 == 0 ?'#1F1F20':'#222222'
                    border{
                        width:1
                        color:index % 2 == 0 ?'#222222':'#1F1F20'
                    }

                    Column{
                        spacing:5
                        anchors{
                            fill:parent
                            margins:10
                        }

                        Rectangle{
                            height:parent.height*.35
                            width:parent.width
                            color:'transparent'

                            Text{
                                id:qs
                                text:title.length>80?title.substr(0,80)+'...':title
                                font.pointSize:12
                                font.bold:true
                                color:'#CCCCCC'
                                wrapMode:Text.WordWrap
                                width:parent.width
                                height:parent.height
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Row{
                            height:25
                            width:parent.width
                            spacing:10

                            //how to declare variables in python
                            //VIEW COUNT
                            Rectangle{
                                height:parent.height
                                width:parent.width*.33
                                color:'#2E2F30'
                                radius:4
                                Row{
                                    anchors.fill:parent
                                    anchors.margins: 0
                                    spacing:2

                                    Rectangle{
                                        height:childrenRect.height+5
                                        width:childrenRect.width+5
                                        color:'transparent'
                                        anchors{
                                            verticalCenter:parent.verticalCenter
                                        }
                                        Text{
                                            text:view_count
                                            font.pointSize:9
                                            color:'white'
                                        }
                                    }

                                    Rectangle{
                                        height:childrenRect.height+5
                                        width:childrenRect.width+5
                                        color:'transparent'
                                        anchors{
                                            verticalCenter:parent.verticalCenter
                                        }

                                        Text{
                                            text:'views'
                                            font.pointSize:9
                                            color:'white'
                                        }

                                        // Image{
                                        //     height:20
                                        //     width:20
                                        //     source:'../assets/icons/.png'
                                        // }
                                        // TextIcon{
                                        //     text:'\uE97F'
                                        //     color:'#CCCCCC'
                                        //     _size:16
                                        //     bold:true
                                        // }
                                    }
                                }
                            }

                            //ANSWER COUNT
                            Rectangle{
                                height:parent.height
                                width:parent.width*.33
                                color:'#2E2F30'
                                radius:4
                                Row{
                                    anchors.fill:parent
                                    anchors.margins: 0
                                    spacing:2

                                    Rectangle{
                                        height:childrenRect.height+5
                                        width:childrenRect.width+5
                                        color:'transparent'
                                        anchors{
                                            verticalCenter:parent.verticalCenter
                                        }

                                        Text{
                                            text:answer_count
                                            font.pointSize:9
                                            color:'white'
                                        }
                                    }

                                    Rectangle{
                                        height:childrenRect.height+5
                                        width:childrenRect.width+5
                                        color:'transparent'
                                        anchors{
                                            verticalCenter:parent.verticalCenter
                                        }
                                        Text{
                                            text:'answers'
                                            font.pointSize:9
                                            color:'white'
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ScrollView{
                anchors.fill: parent
                clip:true

                ListView{
                    spacing:5
                    anchors.fill:parent
                    model:questionmodel
                    delegate:questiondelegate
                }

                // Image{
                //     y:150
                //     width:150
                //     height:width
                //     source:'../assets/icons/stack.png'
                //     anchors.horizontalCenter: parent.horizontalCenter
                // }
                // Text{
                //     text:'Search on STACKOVERFLOW'
                //     anchors.centerIn: parent
                //     color:'white'
                // }
            }
        }
    }
}
