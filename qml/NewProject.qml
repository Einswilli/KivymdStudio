import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs 1.2
import QtCharts 2.15
import QtQuick.Layouts 1.0

Item{
    id:root

    property color bordercolor:'#f3f4f6'
    signal canceled()
    signal created(string path)

    function get_type(){
        if(typekv.checked){
            return 'kv'
        }else if(typepy.checked){
            return 'py'
        }else{
            return 'pykv'
        }
    }

    Rectangle{
        color:'#1F1F20'
        anchors.fill:parent
        Column{
            spacing: 15
            anchors.fill:parent
            anchors.margins:10
            Row{
                height: 40
                width: parent.width
                spacing: 10
                Rectangle{
                    color:'#1F1F20'
                    height: parent.height
                    width: (parent.width/4)-5
                    Row{
                        anchors.fill:parent
                        spacing: 5
                        Rectangle{
                            height: parent.height
                            width: height
                            color:parent.parent.color
                            Image{
                                anchors.fill:parent
                                anchors.margins:5
                                source: '../assets/icons/KvStudio.png'
                            }
                        }
                        Text{
                            text:'Project Name'
                            color:bordercolor
                            font.pixelSize:16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Rectangle{
                    color:'#2E2F30'
                    radius:11
                    height: parent.height
                    width: ((parent.width*3)/4)-5
                    TextField{
                        id:namefield
                        text:'MyKivyApp'
                        placeholderText:'Project Name'
                        placeholderTextColor: '#838485'
                        color:'#FFFFFF'
                        font.pixelSize:16
                        anchors.fill:parent
                        leftPadding: 15
                        topPadding: 9
                        background:Rectangle{
                            color:'#2E2F30'
                            radius:11
                            height: parent.height
                            width: parent.width
                        }
                    }
                }
            }
            Row{
                height: 40
                width: parent.width
                spacing: 10
                Rectangle{
                    color:'#1F1F20'
                    height: parent.height
                    width: (parent.width/4)-5
                    Row{
                        anchors.fill:parent
                        spacing: 5
                        Rectangle{
                            height: parent.height
                            width: height
                            color:parent.parent.color
                            Image{
                                anchors.fill:parent
                                anchors.margins:5
                                source: '../assets/icons/fop.svg'
                            }
                        }
                        Text{
                            text:'Project Folder'
                            color:bordercolor
                            font.pixelSize:16
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Rectangle{
                    color:'#2E2F30'
                    radius:11
                    height: parent.height
                    width: (parent.width/2)+50
                    TextField{
                        id:pathfield
                        text:backend.get_default_proj_dir()
                        placeholderText: 'Choose folder to create the project in'
                        placeholderTextColor: '#838485'
                        color:'#FFFFFF'
                        font.pixelSize:16
                        anchors.fill:parent
                        leftPadding: 9
                        topPadding: 9
                        background:Rectangle{
                            color:'#2E2F30'
                            radius:11
                            height: parent.height
                            width: parent.width
                        }
                    }
                }
                Rectangle{
                    color:'#2E2F30'
                    radius:11
                    height: parent.height
                    width: (parent.width/5)-30
                    border.color:'#464647'
                    Text{
                        text:'change...'
                        color:bordercolor
                        font.pixelSize:16
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
                            //open file dialog
                            projdialog.open()
                        }
                    }
                }
            }
            Rectangle{
                height:40
                width: parent.width
                color:parent.parent.color
                Row{
                    anchors.fill:parent
                    spacing: 10
                    Rectangle{
                        height: parent.height
                        width: (parent.width/4)-5
                        color:parent.parent.color
                        Text{
                            text:'Project Type'
                            color:bordercolor
                            anchors.centerIn:parent
                            font.pixelSize:16
                        }
                    }
                    Rectangle{
                        height: parent.height
                        width: (parent.width/4)-5
                        color:parent.parent.color
                        CheckBox{
                            id:typepy
                            height: 20
                            width: (parent.width/2)-25
                            anchors.verticalCenter:parent.verticalCenter
                            checked:typekv.checked?false:typepykv.checked?false:true
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/images/py.png'
                                        anchors.centerIn:parent
                                        visible:typepy.checked
                                    }
                                }
                                Text{
                                    text:'Python only'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }
                    }
                    Rectangle{
                        height: parent.height
                        width: (parent.width/4)-5
                        color:parent.parent.color
                        anchors.verticalCenter:parent.verticalCenter
                        CheckBox{
                            id:typekv
                            height: 20
                            width: (parent.width/2)-25
                            anchors.verticalCenter:parent.verticalCenter
                            checked:typepy.checked?false:typepykv.checked?false:true
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/images/kv.png'
                                        anchors.centerIn:parent
                                        visible:typekv.checked
                                    }
                                }
                                Text{
                                    text:'Kivy only'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }
                    }
                    Rectangle{
                        height: parent.height
                        width: (parent.width/4)-5
                        color:parent.parent.color
                        CheckBox{
                            id:typepykv
                            height: 20
                            width: (parent.width/2)-25
                            anchors.verticalCenter:parent.verticalCenter
                            checked:typekv.checked?false:typepy.checked?false:true
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/icons/KvStudio.png'
                                        anchors.centerIn:parent
                                        visible:typepykv.checked
                                    }
                                }
                                Text{
                                    text:'Python and kivy'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
            Rectangle{
                height: (parent.height/4)-25
                width: parent.width
                color:parent.parent.color
                Column{
                    height: parent.height-20
                    width: parent.width/2
                    anchors.centerIn:parent
                    spacing: 10
                    // anchors.fill:parent
                    // anchors.margins:15
                    Row{
                        height: parent.height/3
                        width: parent.width
                        spacing: 50
                        CheckBox{
                            id:addgit
                            height: 20
                            width: (parent.width/2)-25
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/icons/file_type_git2.svg'
                                        anchors.centerIn:parent
                                        visible:addgit.checked
                                    }
                                }
                                Text{
                                    text:'Add .git to project'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }
                        CheckBox{
                            id:addenv
                            height: 20
                            width: (parent.width/2)-25
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/icons/folder-container.svg'
                                        anchors.centerIn:parent
                                        visible:addenv.checked
                                    }
                                }
                                Text{
                                    text:'Add venv to project'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }  
                    }
                    Row{
                        height: parent.height/3
                        width: parent.width
                        spacing: 50
                        CheckBox{
                            id:addlis
                            height: 20
                            width: (parent.width/2)-25
                            checked: true
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/icons/lis.svg'
                                        anchors.centerIn:parent
                                        visible:addlis.checked
                                    }
                                }
                                Text{
                                    text:'Add LICENSE'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }
                        CheckBox{
                            id:addcomp
                            height: 20
                            width: (parent.width/2)-25
                            checked: !typepy.checked
                            indicator: Row{
                                height:parent.height
                                spacing: 8
                                width:(parent.width/3)-5
                                Rectangle{
                                    height: 25
                                    width: 25
                                    radius:5
                                    color:'#2E2F30'
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        height: 20
                                        width: 20
                                        source: '../assets/icons/folder-app.svg'
                                        anchors.centerIn:parent
                                        visible:addcomp.checked
                                    }
                                }
                                Text{
                                    text:!addcomp.checked?'Empty project':'With default template'
                                    color:bordercolor
                                    font.pixelSize:14
                                    anchors.verticalCenter:parent.verticalCenter
                                }
                            }
                        }  
                    }
                }
            }
            Rectangle{
                id:templatebox
                height: (parent.height/4)+10
                width: parent.width
                color:parent.parent.color
                property string tem:''
                Component{
                    id:tempdeg
                    Rectangle{
                        height: templates.cellHeight-5
                        width: templates.cellWidth-5
                        color:'#1F1F20'
                        // CheckBox{
                        //     anchors.fill:parent
                        //     checked: isactive
                        //     onCheckedChanged: {
                        //         //checked=!checked
                                // var e
                                // for(let i=0;i<tempmod.count;i++){
                                //     e=tempmod.get(i)
                                //     e.isactive=false
                                //     tempmod.set(i,e)
                                // }
                                // e=tempmod.get(index)
                                // e.isactive=true
                                // tempmod.set(index,e)
                        //     }
                        //     indicator: 
                            Rectangle{
                                anchors.fill:parent
                                color:isactive?'#2E2F30':parent.color
                                Column{
                                    anchors.fill:parent
                                    spacing:2
                                    Image{
                                        height: parent.height-20
                                        width: 50
                                        source: template
                                        anchors.horizontalCenter:parent.horizontalCenter
                                    }
                                    Text{
                                        text:name
                                        color:isactive?'#FFFFFF':'#CCCCCC'
                                        font.pixelSize:14
                                        anchors.horizontalCenter:parent.horizontalCenter
                                    }
                                }
                                MouseArea{
                                    anchors.fill:parent
                                    hoverEnabled: true
                                    onClicked: {
                                        var e
                                        for(let i=0;i<tempmod.count;i++){
                                            e=tempmod.get(i)
                                            e.isactive=false
                                            tempmod.set(i,e)
                                        }
                                        e=tempmod.get(index)
                                        e.isactive=true
                                        tempmod.set(index,e)
                                        templatebox.tem=e.name
                                    }
                                }
                            }
                        //}
                    }
                }
                ListModel{
                    id:tempmod

                    ListElement{
                        name:'Empty'
                        template:'../assets/templates/empty.png'
                        isactive:true
                    }
                    ListElement{
                        name:'Backdrop'
                        template:'../assets/templates/backdrop.png'
                        isactive:false
                    }
                    ListElement{
                        name:'Tabs'
                        template:'../assets/templates/tab.png'
                        isactive:false
                    }
                    ListElement{
                        name:'NavigationDrawer'
                        template:'../assets/templates/nav.png'
                        isactive:false
                    }
                    ListElement{
                        name:'BottomNavigation'
                        template:'../assets/templates/bn.png'
                        isactive:false
                    }
                }
                ScrollView{
                    anchors.fill:parent
                    anchors.margins:5
                    visible: addcomp.checked
                    GridView{
                        id:templates
                        anchors.fill:parent
                        clip:true
                        cellHeight: parent.height
                        cellWidth: width/5
                        model:tempmod
                        delegate: tempdeg
                    }
                }
            }
            Rectangle{
                height: 40
                width: parent.width
                color:parent.parent.color
                Row{
                    anchors.fill:parent
                    spacing: 5
                    Rectangle{
                        height: parent.height
                        width: parent.width/3
                        color:parent.parent.color
                    }
                    Rectangle{
                        height: parent.height
                        width: parent.width/3
                        color:parent.parent.color
                    }
                    Rectangle{
                        height: parent.height
                        width: parent.width/3
                        color:parent.parent.color
                        Row{
                            anchors.fill:parent
                            spacing:5
                            Rectangle{
                                height: parent.height
                                width: parent.width/2
                                color:parent.parent.color
                                Rectangle{
                                    color:'#2E2F30'
                                    radius:8
                                    height: parent.height-10
                                    width: parent.width-30
                                    border.color:'#464647'
                                    anchors.centerIn: parent
                                    Text{
                                        text:'Cancel'
                                        color:bordercolor
                                        font.pixelSize:16
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
                                            root.canceled()
                                        }
                                    }
                                }
                            }
                            Rectangle{
                                height: parent.height
                                width: parent.width/2
                                color:parent.parent.color
                                Rectangle{
                                    color:'#2E2F30'
                                    radius:8
                                    height: parent.height-10
                                    width: parent.width-30
                                    border.color:'#464647'
                                    anchors.centerIn: parent
                                    Text{
                                        text:'Create'
                                        color:bordercolor
                                        font.pixelSize:16
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
                                            bi.running=true
                                            var tm=addcomp.checked?templatebox.tem:''
                                            root.created(backend.newProject(namefield.text,pathfield.text,templatebox.tem,addcomp.checked,addlis.checked,addenv.checked,addgit.checked,root.get_type()))
                                            bi.running=false
                                            root.canceled()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    BusyIndicator{
        id:bi
        height:100
        width:100
        anchors.centerIn:parent
        running:false
    }
    FileDialog{
        id:projdialog
        defaultSuffix: '*.py'
        //fileUrl: url
        //fileUrls: list<url>
        folder: shortcuts.home
        //modality: Qt: : WindowModality
        nameFilters: ["All files (*)"]
        selectExisting: true
        selectFolder: true
        selectMultiple: true
        //selectedNameFilter: string
        //shortcuts: Object
        sidebarVisible: true
        title: 'Choose folder to save the project'
        //visible: bool
        onAccepted:{
            pathfield.text=fileUrl
        }
    }
}