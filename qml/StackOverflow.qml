import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill: parent

    property bool is_answer:false

    Connections {
        target: StackManager
        enabled: true
        ignoreUnknownSignals: false

        //RESULT IS EMITTED FROM BACKEND
        function onResult(value){
            root.is_answer=false
            questionmodel.append(JSON.parse(value))
        }

        //PROCESSING IS EMITTED FROM BACKEND
        function onBusy(value) {
            progressBar.visible=value
        }

        //EXCEPTION IS EMITTED FROM BACKEND
        function onException(argument) {
            // body...
            console.log(argument)
        }

        //A QUESTION ANSWERS ARE EMITTED
        function onAnswered(value){
            answermodel.clear()
            answermodel.append(JSON.parse(value))
            // console.log(value)
            root.is_answer=true
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

            Column{
                anchors.fill:parent
                anchors.margins: 0
                spacing:5

                Rectangle{
                    radius:8
                    color:'transparent'
                    height:parent.height
                    width:parent.width//-height-5

                    TextField{
                        id:question
                        anchors.fill:parent
                        autoScroll: true
                        color:'white'
                        font.family:'monospace'
                        selectByMouse: true
                        font.pointSize:12
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

                ProgressBar {
                    id: progressBar
                    width: parent.width
                    height: 5
                    visible:false
                    indeterminate: true

                    background: Rectangle {
                        color: "teal"
                    }
                }

                // Rectangle{
                //     height:parent.height
                //     width:height
                //     color:'transparent'

                //     Image{
                //         anchors.fill:parent
                //         anchors.margins: 10
                //         source:'../assets/icons/loupe.png'
                //     }
                // }
            }
        }

        Rectangle{
            height: root.height*.88
            width: parent.width
            color:'transparent'
            visible:!root.is_answer
        

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
                        spacing:8
                        anchors{
                            fill:parent
                            margins:10
                        }

                        Rectangle{
                            height:parent.height*.42
                            width:parent.width
                            color:'transparent'
                            clip:true

                            Text{
                                id:qs
                                text:title.length>70?title.substr(0,80)+'...':title
                                font.pointSize:11
                                font.bold:true
                                color:'#CCCCCC'
                                textFormat:TextEdit.RichText
                                wrapMode:Text.WordWrap
                                width:parent.width
                                height:parent.height
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Row{
                            height:25
                            width:parent.width
                            spacing:5

                            //how to declare variables in python
                            //VIEW COUNT
                            Rectangle{
                                height:parent.height
                                width:parent.width*.33
                                color:'#2E2F30'
                                radius:4
                                Row{
                                    anchors.fill:parent
                                    anchors.margins: 5
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
                                width:parent.width*.30
                                color:'#2E2F30'
                                radius:4
                                Row{
                                    anchors.fill:parent
                                    anchors.margins: 5
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
                                            color:'teal'
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

                            //SCORE COUNT
                            Rectangle{
                                height:parent.height
                                width:parent.width*.29
                                color:'#2E2F30'
                                radius:4
                                Row{
                                    anchors.fill:parent
                                    anchors.margins: 5
                                    spacing:2

                                    Rectangle{
                                        height:childrenRect.height+5
                                        width:childrenRect.width+5
                                        color:'transparent'
                                        anchors{
                                            verticalCenter:parent.verticalCenter
                                        }

                                        Text{
                                            text:score
                                            font.pointSize:9
                                            color:'orange'
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
                                            text:'score'
                                            font.pointSize:9
                                            color:'white'
                                        }
                                    }
                                }
                            }
                        }

                        Text{
                            text:'#: '+tags
                            font.pointSize:9
                            color:'white'
                            font.bold:true
                            width:parent.width
                            wrapMode:Text.WordWrap
                        }

                        //BUTTONS
                        Row{
                            height:25
                            width:parent.width
                            spacing:20

                            Rectangle{
                                height:parent.height
                                width:parent.width*.45
                                color:'teal'
                                radius:8

                                Text{
                                    text:'View answers'
                                    font.pointSize:9
                                    color:'white'
                                    font.bold:true
                                    anchors.centerIn: parent
                                }

                                MouseArea{
                                    anchors.fill:parent
                                    hoverEnabled:true

                                    onClicked:{
                                        StackManager.get_answers(id)
                                    }
                                }
                            }

                            Rectangle{
                                height:parent.height
                                width:parent.width*.45
                                color:'#414141'
                                radius:8

                                Text{
                                    text:'Open link'
                                    font.pointSize:9
                                    color:'white'
                                    font.bold:true
                                    anchors.centerIn: parent
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
                    id:list
                    spacing:5
                    anchors.fill:parent
                    model:questionmodel
                    delegate:questiondelegate
                    // visible:root.is_answer?false:true
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

        Rectangle{
            height: root.height*.88
            width: parent.width
            color:'transparent'
            visible:root.is_answer

            ListModel{
                id:answermodel
            }

            Component{
                id:answerdelegate
                Rectangle{
                    height:Math.min(resview.c_heigt+60,300)
                    width:parent.width
                    color:'#292828'
                    radius:8

                    Column{
                        anchors.fill:parent
                        spacing:5
                        anchors.margins: 3

                        Rectangle{
                            height:25
                            width:parent.width
                            color:'transparent'

                            Row{
                                height:parent.height
                                width:parent.width*.74
                                spacing:10

                                // RETURN BUTTON
                                Rectangle{
                                    height:parent.height
                                    width:height
                                    color:'transparent'

                                    Image{
                                        anchors.fill:parent
                                        anchors.margins: 5
                                        source:'../assets/icons/deco.png'
                                        fillMode:Image.PreserveAspectFit
                                        rotation:180
                                    }

                                    MouseArea{
                                        anchors.fill:parent
                                        hoverEnabled:true

                                        onEntered:{
                                            parent.scale=1.2
                                        }

                                        onExited:{
                                            parent.scale=1
                                        }

                                        onClicked:{
                                            root.is_answer=false
                                        }
                                    }
                                }

                                // SCORE
                                Row{
                                    height:parent.height
                                    width:parent.width*.3
                                    spacing:5

                                    Rectangle{
                                        height:parent.height
                                        width:height
                                        color:'transparent'

                                        Image{
                                            anchors.fill:parent
                                            anchors.margins: 2
                                            source:'../assets/icons/score1.png'
                                            fillMode:Image.PreserveAspectFit
                                            // rotation:180
                                        }

                                        MouseArea{
                                            anchors.fill:parent
                                            hoverEnabled:true

                                            onEntered:{
                                                parent.scale=1.2
                                            }

                                            onExited:{
                                                parent.scale=1
                                            }
                                        }
                                    }

                                    Text{
                                        text:score
                                        font.pointSize:9
                                        color:'#DDDDDD'
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                //STATUS
                                Row{
                                    height:parent.height
                                    width:parent.height
                                    visible:is_accepted
                                    spacing:5

                                    Rectangle{
                                        height:parent.height
                                        width:height
                                        color:'transparent'

                                        Image{
                                            anchors.fill:parent
                                            anchors.margins: 1
                                            source:'../assets/icons/status-ok.svg'
                                            fillMode:Image.PreserveAspectFit
                                            // rotation:180
                                        }

                                        MouseArea{
                                            anchors.fill:parent
                                            hoverEnabled:true

                                            onEntered:{
                                                parent.scale=1.2
                                            }

                                            onExited:{
                                                parent.scale=1
                                            }
                                        }
                                    }

                                    // Text{
                                    //     text:score
                                    //     font.pointSize:9
                                    //     color:'#DDDDDD'
                                    //     anchors.verticalCenter: parent.verticalCenter
                                    // }
                                }
                            }

                            Text{
                                text:'Result '+(index+1)
                                font.pointSize:9
                                color:'#DDDDDD'
                                anchors.right:parent.right
                                anchors.margins:10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Rectangle{
                            color:'#1F1F20'
                            height:parent.height-30
                            width:parent.width
                            anchors.bottom:parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            CodeView{
                                id:resview
                                code:content
                                // anchors.fill:parent
                            }
                        }
                    }
                }
            }


            ScrollView{
                anchors.fill: parent
                clip:true

                ListView{
                    spacing:25
                    anchors.fill:parent
                    model:answermodel
                    delegate:answerdelegate
                    // visible:root.is_answer?false:true
                }
            }
        }
    }
}
