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
        id:rect
        anchors.fill:parent
        color: 'transparent'

        // TERMINAL TABVIEW
        TabView{
            id: termtab
            anchors.fill: parent

            style: TabViewStyle {
                frameOverlap: 0
                tab:Rectangle{
                    color: 'transparent'
                    implicitWidth: tabrect.width + 50
                    implicitHeight: 30
                    width:150
                    height:30

                    // ROW
                    RowLayout{
                        anchors.fill: parent
                        spacing: 2
                    
                        Rectangle {
                            id: tabrect
                            color: styleData.selected ? barclaire :moyen
                            // border.color:  barclaire
                            implicitWidth: Math.min(childrenRect.width + 20, 140)
                            implicitHeight: 30
                            width:120
                            height:30
                            radius: 5

                            //  ROW
                            RowLayout{
                                spacing: 10
                                anchors.fill:parent
                                // anchors.margins: 3

                                // TAB ICON
                                Rectangle{
                                    height:parent.height-10
                                    width:height
                                    color:'transparent'
                                    anchors.verticalCenter: parent.verticalCenter
                                    TextIcon{
                                        id: tabicon
                                        _size: 14
                                        text: icons['bash']
                                        anchors.fill: parent
                                        anchors.margins: 3
                                    }
                                }

                                // TAB TITLE TEXTE
                                Text {
                                    id: tabtitle
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: styleData.title
                                    font.pointSize:11
                                    color: styleData.selected ? "white" : '#A4A5A7'
                                }

                                // CLOSE BTN
                                Rectangle{
                                    anchors.verticalCenter: parent.verticalCenter
                                    // anchors.margins: 8
                                    width:15
                                    height:15
                                    radius:3
                                    color:barfonce
                                    visible: termtab.count != 1 

                                    TextIcon{
                                        id:close
                                        _size:10
                                        text:icons['close']
                                        anchors.fill: parent
                                    }

                                    MouseArea{
                                        anchors.fill: parent
                                        hoverEnabled:true
                                        onEntered:{
                                            close.scale = 1.2
                                        }
                                        onExited:{
                                            close.scale = 1
                                        }
                                        onClicked:{
                                            // parent.styleData.selected
                                            termtab.rmTab(styleData.index)
                                        }
                                    }
                                }

                                // Rectangle{
                                //     width:1
                                //     color:'#0A0A0A'
                                //     height:parent.height
                                //     anchors.right:parent.right
                                // }
                            }
                        }

                        // NEW TAB WIDGET
                        Rectangle{
                            id:newtab
                            height: styleData.index == termtab.count-1 ? 30 :0
                            width: styleData.index == termtab.count-1 ? height : 0
                            color: moyen
                            radius: 5
                            clip: true
                            visible: styleData.index == termtab.count-1

                            TextIcon{
                                _size: 14
                                text: icons['plus']
                                anchors.centerIn: parent
                            }

                            MouseArea{
                                anchors.fill: parent
                                hoverEnabled:true
                                onEntered:{
                                    close.scale = 1.2
                                }
                                onExited:{
                                    close.scale = 1
                                }
                                onClicked:{
                                    // parent.styleData.selected
                                    termtab.insertTab(
                                        styleData.index+1,
                                        'shell',
                                        terminalComponent
                                    )
                                }
                            }
                        }

                        // Component.onCompleted:{
                        //     var ext=styleData.title.substr(-3,3)
                        //     //console.log(ext)
                        //     if (ext=='.kv'){
                        //         fileimage.source='../assets/images/kivy.png'
                        //     }
                        //     else if(ext=='.py'){
                        //         fileimage.source='../assets/images/py.png'
                        //     }else if(ext=='ome'){
                        //         fileimage.source='../assets/images/coding.png'
                        //     }else if(ext=='cpp'){
                        //         fileimage.source='../assets/images/cpp.png'
                        //     }else if(ext=='.js'){
                        //         fileimage.source='../assets/images/js.png'
                        //     }else if(ext=='.md'){
                        //         fileimage.source='../assets/images/md.png'
                        //     }else if(ext=='ngs'){
                        //         fileimage.source='../assets/icons/param.png'
                        //     }
                        // }
                    }
                }
                frame: Rectangle { color:'transparent' ; clip:true}
                tabsMovable: true
            }

            // DEFAULT CHILD TAB
            Tab{
                title: 'Shell'
                active: true
                //asynchronous: bool

                // TERMINAL WIDGET
                Terminal{
                    height:parent.height
                    width:parent.width
                    // anchors.fill: parent
                }
            }
        }        
    }

    // COMPONENTS
    Component{
        id: terminalComponent
        Terminal{
            id: terminal
            anchors.fill: parent
            //anchors.margins: 10
        }
    }
}