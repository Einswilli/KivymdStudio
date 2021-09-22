import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
//import Qt5Compat.GraphicalEffects

ApplicationWindow {
    id:root
    width: 1100
    height: 700
    visible: true
    color: "#1F1F20"
    title: qsTr("Kivymd-STudio")

    QtObject{
        objectName: 'backend'
    }

    Connections{
        enabled: true
        ignoreUnknownSignals: false
        target: backend

    }

    property color appcolor:"#1F1F20"
    property color barclaire:'#292828'
    property color barfonce:'#18191A'
    property color moyen:'#2E2F30'
    property color bordercolor:'#535353'
    property color hovercolor:'#609EAD96'

    // Keys.onPressed:{
    //     if(event.key==Qt.key_crtl)
    // }
    
    Rectangle{
        id:leftbar
        width:60
        height:parent.height
        color:'#292828'
        anchors.left: parent.left

        Rectangle{
            width:50
            height:50
            radius:12
            y:30
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:25
                height:25
                source:'../assets/icons/loupe.png'
                anchors.centerIn: parent
            }

            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    parent.color=hovercolor
                }
                onExited:{
                    parent.color=barclaire
                }
                onClicked:{

                }
            }
        }
        Rectangle{
            width:50
            height:50
            radius:12
            y:90
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:25
                height:25
                source:'../assets/icons/fichier.png'
                anchors.centerIn: parent
            }

            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    parent.color=hovercolor
                }
                onExited:{
                    parent.color=barclaire
                }
                onClicked:{

                }
            }
            
        }
        Rectangle{
            width:50
            height:50
            radius:12
            y:150
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:25
                height:25
                source:'../assets/icons/menu(1).png'
                anchors.centerIn: parent
            }

            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    parent.color=hovercolor
                }
                onExited:{
                    parent.color=barclaire
                }
                onClicked:{

                }
            }
            
        }
        Rectangle{
            width:50
            height:50
            radius:12
            y:210
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:25
                height:25
                source:'../assets/icons/github(1).png'
                anchors.centerIn: parent
            }

            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    parent.color=hovercolor
                }
                onExited:{
                    parent.color=barclaire
                }
                onClicked:{

                }
            }
            
        }
        Rectangle{
            width:50
            height:50
            radius:12
            y:parent.height-110
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:35
                height:35
                source:'../assets/icons/coffee4.png'
                anchors.centerIn: parent
            }

            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    parent.color=hovercolor
                }
                onExited:{
                    parent.color=barclaire
                }
                onClicked:{

                }
            }
            
        }
        Rectangle{
            width:50
            height:50
            radius:12
            y:parent.height-60
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:25
                height:25
                source:'../assets/icons/param.png'
                anchors.centerIn: parent
            }

            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    parent.color=hovercolor
                }
                onExited:{
                    parent.color=barclaire
                }
                onClicked:{

                }
            }
            
        }
    }
    Rectangle{
        id:leftbox
        x:leftbar.width
        width:240
        height:parent.height
        color:moyen

        Rectangle{
            width:parent.width
            height:35
            color:moyen
            border.color:bordercolor
            border.width:1
            
            Text{
                y:10
                text:qsTr('Explorer')
                font.pixelSize:12
                color:'white'
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle{
                id:exphead
                width:20
                height:25
                y:5
                color:parent.color
                radius:10
                anchors.right:parent.right
                anchors.margins: 5
                //anchors.verticalCenter: parent.verticalCenter
                
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/men.png'
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        exphead.color=hovercolor
                    }
                    onExited:{
                        exphead.color=moyen
                    }
                    onClicked:{

                    }
                }
            }
        }

        Rectangle{
            id:opt
            x:15
            y:45
            height:45
            color:barfonce
            border.width:1
            border.color:bordercolor
            width:parent.width-15
            Material.elevation:6
        }
    }
    Rectangle{
        id:top_bar
        x:leftbar.width+leftbox.width
        height:40
        color:barfonce
        width:parent.width-leftbar.width-leftbox.width
        anchors.top:parent.top

        Rectangle{
            anchors.right:parent.right
            anchors.margins: 15
            height:parent.height-10
            width:parent.width/3
            y:5
            color:parent.color


        }
    }
    Rectangle{
        id:body
        y:top_bar.height
        color:appcolor
        x:leftbar.width+leftbox.width
        height:parent.height-top_bar.height
        width:parent.width-(leftbar.width+leftbox.width)

        
        TabView{
            id:codetab
            anchors.fill: parent
            style: TabViewStyle {
                frameOverlap: 1
                tab: Rectangle {
                    color: styleData.selected ? barfonce :barclaire
                    border.color:  barclaire
                    implicitWidth: Math.max(text.width + 15, 120)
                    implicitHeight: 20
                    width:120
                    height:40
                    radius: 2
                    

                    Image{
                        id:fileimage
                        height:20
                        width:20
                        x:8
                        y:10
                        source: '' 
                    }

                    Component.onCompleted:{
                        var ext=styleData.title.substr(-3,3)
                        console.log(ext)
                        if (ext=='.kv'){
                            fileimage.source='../assets/images/kivy.png'
                        }
                        else if(ext=='.py'){
                            fileimage.source='../assets/images/py.png'
                        }else if(ext=='ome'){
                            fileimage.source='../assets/images/coding.png'
                        }
                    }

                    Text {
                        id: text
                        anchors.centerIn: parent
                        text: styleData.title
                        font.pixelSize:12
                        color: styleData.selected ? "white" : '#A4A5A7'
                    }

                    Rectangle{
                        anchors.right:parent.right
                        anchors.margins: 8
                        y:10
                        width:15
                        height:15
                        radius:3
                        color:barfonce

                        Text{
                            text:qsTr('×')
                            font.pixelSize:13
                            color:'white'
                            anchors.centerIn: parent
                        }
                    }
                    Rectangle{
                        width:1
                        color:'#0A0A0A'
                        height:parent.height
                        anchors.right:parent.right
                    }
                }
                frame: Rectangle { color: "steelblue" }
                tabsMovable: true
            }
            
            Tab{
                title: 'Wellcome'
                active: true
                //asynchronous: bool
                Rectangle{
                    color:body.color
                    anchors.fill: parent

                    Text{
                        id:weltext
                        text:qsTr('Wellcome To Kivymd Studio')
                        //font.bold:true
                        color:'#C6D6DF'
                        font.pixelSize:48
                        y:80
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                    }

                    Rectangle{
                        x:40
                        y:weltext.height+90
                        width:150
                        height:150
                        color:parent.color
                        border.color:bordercolor
                        border.width:1

                        Image{
                            width:150
                            height:99
                            y:1
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:'../assets/images/android.png'
                        }

                        Text{
                            text:qsTr('Android')
                            color:weltext.color
                            font.pixelSize:14
                            y:114
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                    }

                    Rectangle{
                        x:190+40
                        y:weltext.height+90
                        width:150
                        height:150
                        color:parent.color
                        border.color:bordercolor
                        border.width:1

                        Image{
                            width:110
                            height:99
                            y:1
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:'../assets/images/apple.png'
                        }

                        Text{
                            text:qsTr('Ios')
                            color:weltext.color
                            font.pixelSize:14
                            y:114
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                    }

                    Rectangle{
                        x:230+190
                        y:weltext.height+90
                        width:150
                        height:150
                        color:parent.color
                        border.color:bordercolor
                        border.width:1

                        Image{
                            width:120
                            height:99
                            y:1
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:'../assets/images/win10.png'
                        }

                        Text{
                            text:qsTr('Windows')
                            color:weltext.color
                            font.pixelSize:14
                            y:114
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                    }

                    Rectangle{
                        x:230+380
                        y:weltext.height+90
                        width:150
                        height:150
                        color:parent.color
                        border.color:bordercolor
                        border.width:1

                        Image{
                            width:120
                            height:100
                            y:4
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:'../assets/images/mac.png'
                        }

                        Text{
                            text:qsTr('Mac OS')
                            color:weltext.color
                            font.pixelSize:14
                            y:114
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                    }

                    Rectangle{
                        x:230+380+190
                        y:weltext.height+90
                        width:150
                        height:150
                        color:parent.color
                        border.color:bordercolor
                        border.width:1

                        Image{
                            width:150
                            height:99
                            y:1
                            anchors.horizontalCenter: parent.horizontalCenter
                            source:'../assets/images/linux.png'
                        }

                        Text{
                            text:qsTr('Linux')
                            color:weltext.color
                            font.pixelSize:14
                            y:114
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                    }

                    Rectangle{
                        id:recents
                        x:40
                        y:weltext.height+90+170
                        border.width:1
                        border.color:bordercolor
                        width:350
                        height:300
                        color:barfonce
                    }

                    Rectangle{
                        id:racourscis
                        x:430
                        y:recents.y
                        width:400
                        height:300
                        color:parent.color

                        Rectangle{
                            width:parent.width
                            height:30
                            y:40
                            color:parent.color
                            Text{
                                x:50
                                text:qsTr('New file')
                                color:'#1F4283'
                                font.pixelSize:15
                                font.italic:true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:140
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'crtl'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                            Text{
                                x:190
                                text:'+'
                                color:'#9B9FA5'
                                font.pixelSize:14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:210
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'N'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle{
                            width:parent.width
                            height:30
                            y:80
                            color:parent.color
                            Text{
                                x:50
                                text:qsTr('New folder')
                                color:'#1F4283'
                                font.pixelSize:15
                                font.italic:true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:140
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'crtl'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                            Text{
                                x:190
                                text:'+'
                                color:'#9B9FA5'
                                font.pixelSize:14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:210
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'K'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle{
                            width:parent.width
                            height:30
                            y:120
                            color:parent.color
                            Text{
                                x:50
                                text:qsTr('Open folder')
                                color:'#1F4283'
                                font.pixelSize:15
                                font.italic:true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:140
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'crtl'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                            Text{
                                x:190
                                text:'+'
                                color:'#9B9FA5'
                                font.pixelSize:14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:210
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'N'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                            Text{
                                x:240
                                text:'+'
                                color:'#9B9FA5'
                                font.pixelSize:14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:255
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'O'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle{
                            width:parent.width
                            height:30
                            y:160
                            color:parent.color
                            Text{
                                x:50
                                text:qsTr('Open file')
                                color:'#1F4283'
                                font.pixelSize:15
                                font.italic:true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:140
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'crtl'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                            Text{
                                x:190
                                text:'+'
                                color:'#9B9FA5'
                                font.pixelSize:14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Butts{
                                x:210
                                back_color:parent.color
                                text_color:'#9B9FA5'
                                butt_text:'O'
                                //anchors.verticalCenter: parent.verticalCenter
                            }
                        }


                    }

                    Rectangle{
                        width:90
                        height:50
                        anchors.bottom:parent.bottom
                        anchors.right:parent.right
                        color:parent.color
                        anchors.margins: 2
                        
                        Image{
                            anchors.fill: parent
                            source:'../assets/icons/DotPy.png'
                        }
                    }

                    
                }
                
            }
            Tab{
                title: 'main.py'
                active: true
                //asynchronous: bool
                Rectangle{
                    color:body.color
                    anchors.fill: parent

                    Rectangle{
                        width:60
                        height:parent.height
                        anchors.left:parent.left
                        color:barfonce
                    }
                }
            }

            Tab{
                title: 'main.kv'
                active: true
                //asynchronous: bool
                Rectangle{
                    color:body.color
                    anchors.fill: parent
                }
            }
        }
        
    }
    Rectangle{
        id:terminal
        height:290
        color:barclaire
        x:leftbar.width+leftbox.width
        width:parent.width-leftbar.width-leftbox.width
        border.color:bordercolor
        border.width:1
        anchors.bottom:parent.bottom
        visible:false
    }
    Rectangle{
        id:emmubox
        width:350
        z:10
        y:top_bar.height
        height:parent.height-top_bar.height
        color:barclaire
        border.color:bordercolor
        border.width:1
        anchors.right:parent.right
        visible:false
    }
}
