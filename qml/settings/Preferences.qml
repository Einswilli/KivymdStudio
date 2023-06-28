import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root
    anchors.fill:parent

    property var navs:[editornav,accountnav,appearancenav,openainav]
    property var pages:[editorsettings,appearancesettings,openaisettings,accountsettings]

    function changeNav(nav){
        for (var i=0;i<navs.length;++i) {
            // navs[i].enabled=false
            navs[i].active=false
        }
        nav.enabled=true
        nav.active=true
    }

    function changePage(page){
        for (var i=0;i<pages.length;++i) {
            pages[i].enabled=false
            pages[i].visible=false
        }
        page.enabled=true
        page.visible=true
    }

    
    Component.onCompleted:{
        root.changeNav(editornav);
        root.changePage(editorsettings);
    }

    Rectangle{
        anchors.fill:parent
        color:'transparent'

        Row{
            anchors.fill:parent
            anchors.margins:10
            spacing:10

            //LEFT PANEL
            Rectangle{
                id:leftpanel
                height:parent.height
                width:Math.min((parent.width*.20),220)
                color:'#292828'

                Column{
                    anchors.fill:parent
                    anchors.margins:0
                    spacing:5

                    Rectangle{
                        height:40
                        width:parent.width
                        color:'transparent'
                        Text{
                            text:"Studio Settings"
                            font.bold:true
                            font.pointSize:14
                            color:'#AAAAAA'
                            anchors.centerIn: parent
                        }
                    }

                    //EDITOR
                    Rectangle{
                        height:40
                        width:parent.width
                        color:'transparent'

                        NavItem{
                            id:editornav
                            icon: 'file-code-outline'
                            label: 'Editor'
                            active:true

                            onTapped:{
                                root.changeNav(editornav);
                                root.changePage(editorsettings);
                            }
                        }
                    }

                    // APPEARANCES
                    Rectangle{
                        height:40
                        width:parent.width
                        color:'transparent'

                        NavItem{
                            id:appearancenav
                            icon: 'cookie-check-outline'
                            label: 'Appearance'
                            active:false

                            onTapped:{
                                root.changeNav(appearancenav);
                                root.changePage(appearancesettings);
                            }
                        }
                    }

                    // OPENAI
                    Rectangle{
                        height:40
                        width:parent.width
                        color:'transparent'

                        NavItem{
                            id:openainav
                            icon: 'crown-circle-outline'
                            label: 'OpenAI'
                            active:false

                            onTapped:{
                                root.changeNav(openainav);
                                root.changePage(openaisettings);
                            }
                        }
                    }

                    // ACCOUNT
                    Rectangle{
                        height:40
                        width:parent.width
                        color:'transparent'

                        NavItem{
                            id:accountnav
                            icon: 'account-circle-outline'
                            label: 'Account'
                            active:false

                            onTapped:{
                                root.changeNav(accountnav);
                                root.changePage(accountsettings);
                            }
                        }
                    }
                }
            }

            //RIGHT PANEL
            Rectangle{
                height:parent.height
                width:parent.width-leftpanel.width-10
                color:'Transparent'

                AccountSettings{
                    id:accountsettings
                    anchors.fill:parent
                }

                OpenaiSettings{
                    id:openaisettings
                    anchors.fill:parent
                }

                AppearanceSettings{
                    id:appearancesettings
                    anchors.fill:parent
                }

                EditorSettings{
                    id:editorsettings
                    anchors.fill:parent
                }
            }
        }
    }
}