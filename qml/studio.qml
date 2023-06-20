import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
import QtQuick.Dialogs 1.2
import Qt.labs.folderlistmodel 2.15
import QtQml.Models 2.2
// import QtApplicationManager 2.0
//import QtQuick.Controls 1.4 as OV
//import DotPy.Core 1.0
//import '../highlightcolor.js' as Logic
//import '..highlight.js/lib/core' as Logic
//import ArcGIS.AppFramework.Scripting 1.0
//import Qt5Compat.GraphicalEffects

ApplicationWindow {
    id:root
    width: 1000
    height: 700
    visible: true
    color: "#1F1F20"
    title: qsTr("Kivymd Studio Code")

    QtObject{
        id:obj
        objectName: 'backend'

        function reparse(value){
            var dic=value
            return JSON.parse(JSON.stringify(dic))
        }
    }
    function openProject(value){
        fm.folder=value
        fm.show()
    }

    Connections{
        enabled: true
        ignoreUnknownSignals: false
        target: backend

        function onColorhighlight(value){
            return value
        }
        function onFolderOpen(value){
            return JSON.stringify(value)
        }
        
    }

    Connections{
        enabled:true
        target:FileManagerBackend
        ignoreUnknownSignals: false
    }

    Component.onCompleted: {
        // root.showFullScreen();
        //backend.chargeTree(tree)
        backend.termstdout.connect(root.tstdout)
        root.width=parseInt(backend.getScreen().split(',')[0])
        root.height=parseInt(backend.getScreen().split(',')[1])
        loading.msgt='loading plugins...'
        loading.visible=true
        timer.interval=5000
        timer.running=true
        
        //console.log(l)
        // for(let i of JSON.parse(l)){
        //     console.log(i.name)
        //     loader.sourceComponent = lbarcomp
        //     loader.item.parent = leftcol
        //     loader.item.anchors.horizontalCenter=leftcol.horizontalCenter
        //     loader.item.icon='../plugins/python/'+i.icon
        // }
        //console.log(l)
    }

    function onLogEvent(value){
        console.log(balue)
    }

    function verify(lst,word ){
        var found=false
        for (let w of lst){
            if (w==word){
                console.log(w)
                found=true
                break
            }
            else{
                found=false
            }
        }
        //console.log(found)
        return found
    }

    function removeTab(){
        codetab.remove(codetab.currentIndex)
    }

    function colorify(text) {
        //import hljs from 'highlight.js/lib/core';
        //import python from 'highlight.js/lib/languages/python';
        try {
            Logic.hljs.registerLanguage('python', python);
            return Logic.hljs.highlight(text, { language: "python" });

        } catch (error) {
            //console.log(error)
        }
    }

    function high_l(value){
        return value.toHtmlObject
    }
    

    property color appcolor:"#1F1F20"
    property color barclaire:'#292828'
    property color barfonce:'#18191A'
    property color moyen:'#2E2F30'
    property color bordercolor:'#535353'
    property color hovercolor:'#609EAD96'
    property string emustate:'off'
    property string cde
    property string lnk
    property string imsource
    property string currentFolder
    signal emuLog(var msg)
    signal tstdout(string value)


    onTstdout:{
        console.log(value);
    }

    Shortcut {
        sequence: "Ctrl+T"
        onActivated: terminal.visible=true
    }
    Shortcut {
        sequence: "Alt+Ctrl+T"
        onActivated: terminal.visible=false
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            //console.log('new file')
            fileop.visible=true
        }
    }
    Shortcut {
        sequence: "Ctrl+O"
        onActivated: {
            //console.log('open file')
            opfile.open()
        }
    }
    Shortcut {
        sequence: "Ctrl+K"
        onActivated:{ 
            //console.log(' folder new')
            foldn.visible=true
        }
    }
    Shortcut {
        sequence: "Alt+Ctrl+K"
        onActivated: {
            //console.log('open folder')
            opfold.open()
        }
    }
    Shortcut {
        sequence: "Ctrl+Z"
        onActivated: {
            console.log('undo')
            codetab.getTab(codetab.currentIndex).item.cd.undo()
        }
    }
    Shortcut {
        sequence: "Ctrl+Y"
        onActivated: {
            console.log('redo')
            codetab.getTab(codetab.currentIndex).item.cd.redo()
        }
    }
    Shortcut {
        sequence: "Ctrl+S"
        //enabled:parent.focus
        onActivated: {
            cde=codetab.getTab(codetab.currentIndex).item.cd.getText(0,codetab.getTab(codetab.currentIndex).item.cd.length)
            backend.savefile(codetab.getTab(codetab.currentIndex).item.lk.toString(),backend.get_filename(codetab.getTab(codetab.currentIndex).item.lk),cde)
        }
    }
    // Shortcut {
    //     sequence: "Ctrl+S"
    //     onActivated: console.log('save file')
    // }
    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: {
            console.log('save file as...')
        }
    }
    
    
    //LEFT BAR
    Rectangle{
        id:leftbar
        width:60
        height:parent.height-30
        color:barclaire
        anchors.left: parent.left
        property var pluglist:[xte,git,tree,searchbox,chatgpt,stackoverflow]
        function leftNavigation(s){
            for (let a in pluglist){
                pluglist[a].visible=false;
                pluglist[a].enabled=false;
            }
            s.visible=true;
            s.enabled=true;
        }

        Rectangle{
            id:xhov
            height:parent.height
            width:3
            color:'white'
            anchors.left:parent.left
            visible:false
        }

        Component{
            id:lbarcomp
            Rectangle{
                height:50
                width:50
                radius:12
                color:barclaire
                anchors.horizontalCenter: parent.horizontalCenter

                Image{
                    width:25
                    height:25
                    source:icon
                    anchors.centerIn: parent
                    fillMode:Image.PreserveAspectFit
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
                        xhov.visible=true
                        xhov.parent=parent
                        //console.log(ui)
                        if (leftbox.width==0){
                            exptxt.text=name
                            lb_on.start();
                            expbox.visible=true
                            leftbar.leftNavigation(ui);
                        }
                        else if(leftbox.width>0 && ui.visible==true){
                            expbox.visible=false
                            ui.visible=false
                            lb_off.start()
                        }
                        else{
                            exptxt.text=name
                            leftbar.leftNavigation(ui);
                        }
                    }
                }
            }
        }
        ListModel{
            id:lbarmod
        }

        Component.onCompleted:{
            lbarmod.append({name:'EXPLORER',icon:'../assets/icons/fichier.png',ui:tree})
            lbarmod.append({name:'SEARCH',icon:'../assets/icons/loupe.png',ui:searchbox})
            lbarmod.append({name:'EXTENSIONS',icon:'../assets/icons/plugins.png',ui:xte})
            lbarmod.append({name:'GITHUB',icon:'../assets/icons/github.png',ui:git})
            lbarmod.append({name:'OPENIA CHAT',icon:'../assets/icons/gpt.png',ui:chatgpt})
            lbarmod.append({name:'STACK OVERFLOW',icon:'../assets/icons/stack2.png',ui:stackoverflow})
            var l = obj.reparse(backend.loadPlugins())
            for(let i of JSON.parse(l)){
                var cc=Qt.createComponent('../'+i.template)
                if(cc.status==Component.ready){
                    console.log(i.template)
                    var c=cc.createObject(Rectangle,{height:200,width:100})
                    pluglist.push(c)
                    lbarmod.append({name:i.name,icon:'../plugins/python/'+i.icon,ui:c})
                }else{
                    console.log(cc.errorString())
                }
                //console.log(c)
            }
            //lbarmod.append(JSON.parse(l));
        }

        ScrollView{
            id:scleftcol
            anchors.fill:parent
            ListView{
                spacing:10
                anchors.fill:parent
                clip:true
                delegate:lbarcomp
                model:lbarmod
            }
        }
        
        //COFFEE
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

        //SETTINGS
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
                    paramMenu.open()
                }
            }
            Menu{
                id:paramMenu
                height: 250
                width: 200
                x:parent.width
                y:parent.parent.height-height-50
                background: Rectangle{
                    color:barclaire
                    anchors.fill:parent
                    border.color:bordercolor
                    border.width: 1
                }
                MenuItem{
                    Text{
                        text:'Highlight Theme'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Highlight Theme'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Highlight Theme'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Highlight Theme'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Highlight Theme'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    NumberAnimation{
        id:lb_on
        from: 0
        to: (root.width/5)
        duration: 200
        property: 'width'
        target:leftbox
    }
    NumberAnimation{
        id:lb_off
        from: (root.width/5)
        to: 0
        duration: 200
        property: 'width'
        target:leftbox
    }

    //LEFT BOX
    Rectangle{
        id:leftbox
        x:leftbar.width
        width:(root.width/5)
        height:parent.height-30
        color:moyen

        Rectangle{
            id:expbox
            width:parent.width
            height:35
            color:moyen
            border.color:bordercolor
            border.width:1
            
            Text{
                id:exptxt
                y:10
                text:qsTr('Explorer')
                font.pointSize:12
                color:'white'
                font.bold:true
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
                        opt.visible=true
                    }
                }
            }
        }

        //SEARCH BOX
        Rectangle{
            id:searchbox
            y:expbox.height+1
            width:parent.width
            height:parent.height-expbox.height-2
            color:parent.color
            visible:false

            SearchBox{
                anchors.fill:parent
            }
        }

        //TREE TAB
        Rectangle{
            id:tree
            y:expbox.height
            color:parent.color
            width:parent.width
            height:parent.height-expbox.height
            objectName:'folder'
            clip: true

            FileManager{
                id:fm
                anchors.fill: parent
                bscolor:parent.color
                onFileSelected:{
                    //console.log(file,'11111111')
                    var tx=backend.openfile(file)
                    cde=tx
                    lnk=file.toString()
                    var tl=backend.get_filename(file)
                    if(codetab.contains(tl)==true){
                        let idx=codetab.indexOf(tl)
                        if(codetab.currentIndex>idx){
                            codetab.currentIndex-=codetab.currentIndex-idx
                        }else if(codetab.currentIndex<idx){
                            codetab.currentIndex+=idx-codetab.currentIndex
                        }else{
                            //nothings!
                        }
                    }else{
                        if (tl.substr(-4,4)=='.png' ||tl.substr(-4,4)=='.PNG' ||tl.substr(-4,4)=='.jpg' ||tl.substr(-4,4)=='.JPG' ||tl.substr(-5,5)=='.jpeg' ||tl.substr(-5,5)=='.JPEG' ||tl.substr(-4,4)=='.svg' ||tl.substr(-5,5)=='.webp' ||tl.substr(-5,5)=='.WEBP'){
                            imsource=file
                            codetab.insertTab(codetab.currentIndex+1,tl,imcomp)
                        }else{
                            codetab.insertTab(codetab.currentIndex+1,tl,cb)
                        }
                    }
                    //codetab.getTab(codetab.currentIndex+1).visible=true
                }
                onFolderSwiped:{
                    root.currentFolder=path;
                    console.log(root.currentFolder)
                }
            }

            Component{
                id:imcomp
                Rectangle{
                    id:imrect
                    color:root.color
                    width:codetab.width-400
                    height:codetab.height-200
                    anchors.centerIn: parent
                    Image{
                        id:imv
                        width:parent.width-200
                        height:parent.height-200
                        fillMode:Image.PreserveAspectFit
                        //anchors.fill: imrect
                        anchors.centerIn: parent
                        source:''
                    }
                    Component.onCompleted:{
                        imv.source=imsource
                    }
                }
            }
        }

        //EXTENTIONS TAB
        Rectangle{
            id:xte
            y:expbox.height+1
            width:parent.width
            height:parent.height-expbox.height-2
            color:parent.color
            visible:false
            Text{
                text:'Extentions'
                anchors.centerIn: parent
                color:'white'
            }
        }

        //GIT TAB
        Rectangle{
            id:git
            y:expbox.height+1
            width:parent.width
            height:parent.height-expbox.height-2
            color:parent.color
            visible:false
            Image{
                y:150
                width:150
                height:200
                source:'../assets/icons/git.png'
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text{
                text:'Github'
                anchors.centerIn: parent
                color:'white'
            }
        }

        //CHAT
        Rectangle{
            id:chatgpt
            y:expbox.height+1
            width:parent.width
            height:parent.height-expbox.height-2
            color:parent.color
            visible:false

            ChatView{
                anchors.fill:parent
            }

            // Image{
            //     y:150
            //     width:150
            //     height:width
            //     source:'../assets/icons/chatgpt.png'
            //     anchors.horizontalCenter: parent.horizontalCenter
            // }
            // Text{
            //     text:'OpenIA  chat'
            //     anchors.centerIn: parent
            //     color:'white'
            // }
        }

        //STACKOVERFLOW
        Rectangle{
            id:stackoverflow
            y:expbox.height+1
            width:parent.width
            height:parent.height-expbox.height-2
            color:parent.color
            visible:false

            StackOverflow{
                anchors.fill:parent
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
            visible:false

            Rectangle{
                width:18
                height:18
                radius:20
                color:barclaire
                anchors.right:parent.right
                anchors.margins:5
                anchors.verticalCenter: parent.verticalCenter

                Text{
                    text:qsTr('×')
                    color:'white'
                    font.pixelSize:12
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        parent.color=hovercolor
                    }
                    onExited:{
                        parent.color=barfonce
                    }
                    onClicked:{
                        opt.visible=false
                    }
                }
                
            }

            Rectangle{
                width:20
                height:20
                x:10
                radius:8
                color:parent.color
                anchors.verticalCenter: parent.verticalCenter

                Image{
                    width:17
                    height:17
                    source:'../assets/icons/addfile.png'
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        parent.color=hovercolor
                    }
                    onExited:{
                        parent.color=barfonce
                    }
                    onClicked:{
                        fileop.visible=true
                    }
                }
            }
            Rectangle{
                width:20
                height:20
                x:40
                radius:8
                color:parent.color
                anchors.verticalCenter: parent.verticalCenter

                Image{
                    width:17
                    height:17
                    source:'../assets/icons/folderadd.png'
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        parent.color=hovercolor
                    }
                    onExited:{
                        parent.color=barfonce
                    }
                    onClicked:{
                        foldn.visible=true
                    }
                }
                
            }

            Rectangle{
                width:20
                height:20
                x:70
                radius:8
                color:parent.color
                anchors.verticalCenter: parent.verticalCenter

                Image{
                    width:17
                    height:17
                    source:'../assets/icons/ref.png'
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        parent.color=hovercolor
                    }
                    onExited:{
                        parent.color=barfonce
                    }
                    onClicked:{
                        
                    }
                }
                
            }
        }
        

        //RESIZER
        Rectangle{
            width: 4
            height: parent.height
            color:'transparent'
            anchors.top: parent.top
            anchors.right: parent.right
            MouseArea {
                id: resizeArea
                width: 4
                height: parent.height
                anchors.fill:parent
                anchors.right: parent.right
                cursorShape: Qt.SizeFDiagCursor

                property int startX: 0
                property int startY: 0

                onPressed: {
                    startX = mouseX
                    startY = mouseY
                }
                onPressedChanged: parent.color='transparent'

                onExited: parent.color='transparent'

                onMouseXChanged: {
                    parent.color='teal'
                    if (mouse.buttons === Qt.LeftButton) {
                        var deltaX = mouseX - startX
                        var deltaY = mouseY - startY

                        var newWidth = leftbox.width + deltaX
                        leftbox.width = Math.max(150, Math.min(newWidth, (root.width*2/5)))


                        startX = mouseX
                        startY = mouseY
                    }
                }
            }
        }
    }


    //TOP BAR
    Rectangle{
        id:top_bar
        x:leftbar.width+leftbox.width
        height:40
        color:barfonce
        width:parent.width-leftbar.width-leftbox.width
        anchors.top:parent.top

        Rectangle{
            width:(parent.width*2/3)-10
            height:parent.height-10
            anchors.left:parent.left
            anchors.margins: 5
            color:parent.color
            anchors.verticalCenter: parent.verticalCenter

            Row{
                spacing: 10
                topPadding:12
                height: parent.height
                Rectangle{
                    //x:10
                    height:parent.height
                    width:70
                    color:top_bar.color
                    anchors.verticalCenter: parent.verticalCenter
                    Text{
                        text:'Files'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        anchors.centerIn: parent
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled:true
                        onClicked:{
                            filesmen.open()
                        }
                        onEntered:{
                            parent.color=hovercolor
                        }
                        onExited:{
                            parent.color=top_bar.color
                        }
                    }
                }
                
                Rectangle{
                    //x:90
                    height:parent.height
                    color:top_bar.color
                    anchors.verticalCenter: parent.verticalCenter
                    width:70
                    Text{
                        text:'Edition'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        anchors.centerIn: parent
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled:true
                        onClicked:{
                            editmen.open()
                        }
                        onEntered:{
                            parent.color=hovercolor
                        }
                        onExited:{
                            parent.color=top_bar.color
                        }
                    }
                }

                Rectangle{
                    //x:170
                    height:parent.height
                    color:top_bar.color
                    anchors.verticalCenter: parent.verticalCenter
                    width:70
                    Text{
                        text:'Terminal'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        anchors.centerIn: parent
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled:true
                        onClicked:{
                            terminalmen.open()
                        }
                        onEntered:{
                            parent.color=hovercolor
                        }
                        onExited:{
                            parent.color=top_bar.color
                        }
                    }
                }
                Rectangle{
                    //x:250
                    id:plug
                    height:parent.height
                    color:top_bar.color
                    anchors.verticalCenter: parent.verticalCenter
                    width:70
                    Text{
                        text:'Plugins'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        anchors.centerIn: parent
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled:true
                        onClicked:{
                            pluginsmen.open()
                        }
                        onEntered:{
                            parent.color=hovercolor
                        }
                        onExited:{
                            parent.color=top_bar.color
                        }
                    }
                }
                Rectangle{
                    //x:250
                    height:parent.height
                    color:top_bar.color
                    anchors.verticalCenter: parent.verticalCenter
                    width:70
                    Text{
                        text:'Help'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        anchors.centerIn: parent
                    }
                    MouseArea{
                        anchors.fill: parent
                        hoverEnabled:true
                        onClicked:{
                            helpmen.open()
                        }
                        onEntered:{
                            parent.color=hovercolor
                        }
                        onExited:{
                            parent.color=top_bar.color
                        }
                    }
                }
            }
        }

        Menu{
            id:pluginsmen
            x:plug.x+5
            y:top_bar.height
            // title: string
            // delegate: Component
            // contentModel: model
            width:200
            //height:250
            background: Rectangle{
                color:barclaire
                border.width:1
                anchors.fill: parent
                border.color:bordercolor
            }
            MenuItem{
                Text{
                    text:'Install Plugin'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    //fileop.visible=true
                    //console.log('install plugin')
                    plugdialog.open()
                }
            }
            MenuItem{
                Text{
                    text:'Plugins List'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    //fileop.visible=true
                    //console.log('list plugins')
                }
            }
            MenuItem{
                Text{
                    text:'Uninstall Plugin'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    //fileop.visible=true
                    //console.log('install plugins')
                }
            }
        }
        
        Menu{
            id:helpmen
            x:260
            y:top_bar.height
            width:150
            height:100
            background: Rectangle{
                color:barclaire
                border.width:1
                anchors.fill: parent
                border.color:bordercolor
            }
            MenuItem{
                Text{
                    text:'Help'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MenuItem{
                Text{
                    text:'About'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        Menu{
            id:terminalmen
            x:180
            y:top_bar.height
            width:250
            height:100
            background: Rectangle{
                color:barclaire
                border.width:1
                anchors.fill: parent
                border.color:bordercolor
            }
            MenuItem{
                Text{
                    text:'New Terminal  Ctrl + t'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    terminal.visible=true
                }
            }
            MenuItem{
                Text{
                    text:'Close Terminal  Alt+ Ctrl +t'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    terminal.visible=false
                }
            }
        }
        Menu{
            id:editmen
            x:100
            y:top_bar.height
            width:200
            height:200
            background: Rectangle{
                color:barclaire
                border.width:1
                anchors.fill: parent
                border.color:bordercolor
            }
            MenuItem{
                Text{
                    text:'Copy   Ctrl + C'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MenuItem{
                Text{
                    text:'Cut    Ctrl + X'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MenuItem{
                Text{
                    text:'Paste   Ctrl + V'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MenuItem{
                Text{
                    text:'Redo   Ctrl + R'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MenuItem{
                Text{
                    text:'Undo   Ctrl + Z'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        Menu{
            id:filesmen
            x:10
            y:top_bar.height
            // title: string
            // delegate: Component
            // contentModel: model
            width:200
            height:250
            background: Rectangle{
                color:barclaire
                border.width:1
                anchors.fill: parent
                border.color:bordercolor
            }
            MenuItem{
                Text{
                    text:'New file'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/File-plus.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    fileop.visible=true
                }
            }
            MenuItem{
                Text{
                    text:'Open file'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/File.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    opfile.open()
                }
            }
            MenuItem{
                Text{
                    text:'New folder'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/Folder-plus.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked: {
                    foldn.visible=true
                }
            }
            MenuItem{
                Text{
                    text:'Open folder'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/Folder.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked:{
                    opfold.open()
                }
            }
            MenuItem{
                Text{
                    text:'New Project'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/Compilation.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked: {
                    newproj.open()
                }
            }
            MenuItem{
                Text{
                    text:'Open Project'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/Compilation.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked: {
                    //newproj.open()
                }
            }
            MenuItem{
                Text{
                    text:'Save file'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/File-done.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                onClicked: {
                    cde=codetab.getTab(codetab.currentIndex).item.cd.getText(0,codetab.getTab(codetab.currentIndex).item.cd.length)
                    backend.savefile(codetab.getTab(codetab.currentIndex).item.lk.toString(),backend.get_filename(codetab.getTab(codetab.currentIndex).item.lk),cde)
                }
            }
            MenuItem{
                Text{
                    text:'Save as'
                    color:'#3B7EAC'
                    font.pixelSize:15
                    x:15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Image{
                    width:20
                    height:20
                    source:'../assets/icons/DownloadedFile.svg'
                    anchors.right:parent.right
                    anchors.margins:15
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            
        }
        

        Rectangle{
            anchors.right:parent.right
            anchors.margins: 15
            height:parent.height-10
            width:parent.width/2
            y:5
            color:parent.color
            Rectangle{
                height:parent.height
                width:(parent.width*2)/3
                color:parent.color
                Row{
                    anchors.fill:parent
                    spacing:15
                    Rectangle{
                        id:runer
                        width:height
                        height:parent.height
                        radius:6
                        color:parent.parent.color
                        Image{
                            id:runimg
                            width:20
                            height:20
                            source:'../assets/icons/run-file.svg'
                            anchors.centerIn: parent
                        }
                        MouseArea{
                            anchors.fill:parent
                            hoverEnabled: true
                            onEntered: {
                                parent.scale=1.2
                            }
                            onExited: {
                                parent.scale=1
                            }
                            onClicked: {
                                
                            }
                        }
                    }
                    Rectangle{
                        width:height
                        height:parent.height
                        radius:6
                        color:parent.parent.color
                        Image{
                            width:20
                            height:20
                            source:'../assets/icons/run-tests.svg'
                            anchors.centerIn: parent
                        }
                        MouseArea{
                            anchors.fill:parent
                            hoverEnabled: true
                            onEntered: {
                                parent.scale=1.2
                            }
                            onExited: {
                                parent.scale=1
                            }
                            onClicked: {
                                
                            }
                        }
                    }
                    Rectangle{
                        width:height
                        height:parent.height
                        radius:6
                        color:parent.parent.color
                        Image{
                            width:20
                            height:20
                            source:'../assets/icons/stop.svg'
                            anchors.centerIn: parent
                        }
                        MouseArea{
                            anchors.fill:parent
                            hoverEnabled: true
                            onEntered: {
                                parent.scale=1.2
                            }
                            onExited: {
                                parent.scale=1
                            }
                            onClicked: {
                                
                            }
                        }
                    }
                    Rectangle{
                        width:height
                        height:parent.height
                        radius:6
                        color:parent.parent.color
                        Image{
                            width:20
                            height:20
                            source:'../assets/icons/status-unknown.svg'
                            anchors.centerIn: parent
                        }
                        MouseArea{
                            anchors.fill:parent
                            hoverEnabled: true
                            onEntered: {
                                parent.scale=1.2
                            }
                            onExited: {
                                parent.scale=1
                            }
                            onClicked: {
                                
                            }
                        }
                    }
                }
            }
            Rectangle{
                //x:90
                color:parent.color
                height:parent.height
                width:emimg.width+4
                radius:6
                anchors.right:parent.right
                anchors.margins: 50+list.width

                // Text{
                //     text:'Emulator'
                //     color:'#5E6266'
                //     font.pixelSize:14
                //     x:5
                //     anchors.verticalCenter: parent.verticalCenter
                // }
                Image{
                    id:emimg
                    width:22
                    height:22
                    source:'../assets/icons/emu.png'
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        //parent.color=hovercolor
                    }
                    onExited:{
                        parent.color=top_bar.color
                    }
                    onClicked:{
                        if(emmubox.visible==true){
                            emu_off.start()
                            emmubox.visible=false
                            emustate='off'
                            //backend.emulator()
                        }else{
                            //backend.emulator()
                            emu_on.start()
                            emmubox.visible=true
                            emustate='on'
                            
                        }
                    }
                }
            }

            Rectangle{
                id:list
                width:24
                height:parent.height-2
                anchors.right:parent.right
                radius:4
                color:parent.color
                border.color:bordercolor
                border.width:1
                anchors.margins: 30
                anchors.verticalCenter: parent.verticalCenter
                Image{
                    source:'../assets/icons/list.png'
                    width:parent.width-5
                    height:parent.height-5
                    anchors.centerIn: parent
                }

                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onClicked:{
                        avd.open()
                    }
                    onEntered:{
                        parent.color=hovercolor
                    }
                    onExited:{
                        parent.color=top_bar.color
                    }
                }
                
            }
            Menu{
                id:avd
                y:top_bar.height
                width:200
                height:250
                x:list.x
                //anchors.right:parent.right
                //anchors.margins: 15
                
                background:Rectangle{
                    anchors.fill: parent
                    color:barclaire
                }
                MenuItem{
                    Text{
                        text:'Android 11'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Android 10  '
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Android 9'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Iphone 12'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Iphone 11'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MenuItem{
                    Text{
                        text:'Iphone 7'
                        color:'#3B7EAC'
                        font.pixelSize:15
                        x:15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }


    //BODY
    Rectangle{
        id:body
        y:top_bar.height
        color:appcolor
        x:leftbar.width+leftbox.width
        height:parent.height-top_bar.height-30
        width:root.width-x//leftbar.width-leftbox.width
        clip:true

        
        TabView{
            id:codetab
            anchors.fill: parent
            style: TabViewStyle {
                frameOverlap: 1
                tab: Rectangle {
                    color: styleData.selected ? barfonce :barclaire
                    border.color:  barclaire
                    implicitWidth: Math.max(childrenRect.width + 20, 140)
                    implicitHeight: 20
                    width:120
                    height:40
                    radius: 2

                    Text {
                        id: text
                        x:33
                        anchors.verticalCenter: parent.verticalCenter
                        text: styleData.title
                        font.pointSize:12
                        color: styleData.selected ? "white" : '#A4A5A7'
                    }
                    
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
                        //console.log(ext)
                        if (ext=='.kv'){
                            fileimage.source='../assets/images/kivy.png'
                        }
                        else if(ext=='.py'){
                            fileimage.source='../assets/images/py.png'
                        }else if(ext=='ome'){
                            fileimage.source='../assets/images/coding.png'
                        }else if(ext=='cpp'){
                            fileimage.source='../assets/images/cpp.png'
                        }else if(ext=='.js'){
                            fileimage.source='../assets/images/js.png'
                        }else if(ext=='.md'){
                            fileimage.source='../assets/images/md.png'
                        }
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
                            font.pointSize:13
                            color:'white'
                            anchors.centerIn: parent
                        }
                        MouseArea{
                            anchors.fill: parent
                            hoverEnabled:true
                            onEntered:{
                                parent.color=hovercolor
                            }
                            onExited:{
                                parent.color=barfonce
                            }
                            onClicked:{
                                // parent.styleData.selected
                                codetab.rmTab(styleData.index)
                            }
                        }
                    }
                    Rectangle{
                        width:1
                        color:'#0A0A0A'
                        height:parent.height
                        anchors.right:parent.right
                    }
                }
                frame: Rectangle { color: root.color ; clip:true}
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
                        text:qsTr('Welcome To Kivymd Studio')
                        //font.bold:true
                        color:'#C6D6DF'
                        font.pixelSize:parent.height/12
                        y:parent.height/10
                        anchors.horizontalCenter: parent.horizontalCenter

                        
                    }
                    Rectangle{
                        y:weltext.height+weltext.y+10
                        height:(parent.height/4)+15
                        width:parent.width//-120
                        color:parent.color

                        Row{
                            anchors.fill:parent
                            anchors.margins:15
                            spacing:30
                            Rectangle{
                                height:parent.height-10
                                width:(parent.width/5)-30
                                color:parent.parent.color
                                DeviceBox{
                                    id:android
                                    src:'../assets/images/android.png'
                                    name:'Android'
                                    text_color:weltext.color
                                    rect_height:parent.width
                                    rect_width:parent.width
                                    // anchors.left:parent.left
                                    // anchors.margins: 80
                                    //y:linux.y
                                    back:parent.color
                                }
                            }
                            Rectangle{
                                height:parent.height-10
                                width:(parent.width/5)-30
                                color:parent.parent.color
                                DeviceBox{
                                    id:ios
                                    src:'../assets/images/aple.png'
                                    name:'IOs X'
                                    text_color:weltext.color
                                    rect_height:parent.width
                                    rect_width:parent.width
                                    // anchors.left:parent.left
                                    // anchors.margins: android.rect_width+120
                                    back:parent.color
                                    //y:linux.y
                                }
                            }
                            Rectangle{
                                height:parent.height-10
                                width:(parent.width/5)-30
                                color:parent.parent.color
                                DeviceBox{
                                    id:win10
                                    src:'../assets/images/windows.png'
                                    name:'Windows'
                                    text_color:weltext.color
                                    rect_height:parent.width
                                    rect_width:parent.width
                                    //anchors.horizontalCenter: parent.horizontalCenter
                                    back:parent.color
                                    //y:linux.y
                                }
                            }
                            Rectangle{
                                height:parent.height-10
                                width:(parent.width/5)-30
                                color:parent.parent.color
                                DeviceBox{
                                    id:macos
                                    src:'../assets/images/macos.png'
                                    name:'Mac Os'
                                    text_color:weltext.color
                                    rect_height:parent.width
                                    rect_width:parent.width
                                    // anchors.right:parent.right
                                    // anchors.margins: linux.rect_width+120
                                    back:parent.color
                                    //y:linux.y
                                }
                            }
                            Rectangle{
                                height:parent.height-10
                                width:(parent.width/5)-30
                                color:parent.parent.color
                                DeviceBox{
                                    id:linux
                                    src:'../assets/images/linux.png'
                                    name:'Linux'
                                    text_color:weltext.color
                                    rect_height:parent.width
                                    rect_width:parent.width
                                    // anchors.right:parent.right
                                    // anchors.margins: 80
                                    back:parent.color
                                    //y:5//weltext.height+weltext.y+10
                                }
                            }
                        }
                    }
                    
                    Rectangle{
                        y:weltext.height+60+linux.height
                        width:parent.width
                        color:parent.color
                        height:(parent.height/4)+50
                        anchors.bottom:parent.bottom
                        anchors.margins: 20
                        

                        Rectangle{
                            id:recents
                            //x:parent.width/5
                            // y:weltext.height+90+170
                            // border.width:1
                            // border.color:bordercolor
                            width:(parent.width/4)+30
                            height:parent.height-10
                            color:'transparent'//barfonce
                            anchors.left:parent.left
                            anchors.margins: 90
                            anchors.verticalCenter: parent.verticalCenter
                            Text{
                                id:uit
                                text:qsTr('Recents')
                                font.pointSize:14
                                font.bold:true
                                color:bordercolor
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Rectangle{
                                y:uit.height+10
                                height:parent.height-uit.height-11
                                width:parent.width-2
                                anchors.horizontalCenter: parent.horizontalCenter
                                color:parent.color
                                Component.onCompleted:{
                                    recmod.append(JSON.parse(backend.recents()))
                                }

                                Component{
                                    id:lcomp
                                    Rectangle{
                                        width:rlist.width-4
                                        height:30
                                        color:'transparent'
                                        //anchors.horizontalCenter: parent.horizontalCenter
                                        
                                        Text{
                                            id:rtx
                                            x:5
                                            text:name
                                            font.pixelSize:14
                                            color:'#4FA3E7'
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle{
                                            width:50
                                            height:parent.height-10
                                            radius:6
                                            anchors.right:parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.margins: 5
                                            color:'#5699D8'
                                            
                                            Text{
                                                text:'open'
                                                anchors.centerIn: parent
                                                font.pixelSize:14
                                                color:'white'
                                            }
                                            MouseArea{
                                                anchors.fill:parent
                                                hoverEnabled:true
                                                onClicked:{
                                                    var tx=backend.openfile('file://'+rtx.text)
                                                    // cde=tx
                                                    // lnk='file://'+rtx.text.toString()
                                                    // var tl=backend.get_filename('file://'+rtx.text)
                                                    // if (tl.substr(-4,4)=='.png' ||tl.substr(-4,4)=='.PNG' ||tl.substr(-4,4)=='.jpg' ||tl.substr(-4,4)=='.JPG' ||tl.substr(-5,5)=='.jpeg' ||tl.substr(-5,5)=='.JPEG' ||tl.substr(-4,4)=='.svg' ||tl.substr(-5,5)=='.webp' ||tl.substr(-5,5)=='.WEBP'){
                                                    //     imsource='file://'+rtx.text
                                                    //     codetab.insertTab(codetab.currentIndex+1,tl,imcomp)
                                                    // }else{
                                                    //     codetab.insertTab(codetab.currentIndex+1,tl,cb)
                                                    // }
                                                    //console.log()
                                                    // backend.openfile(rtx.text)
                                                    fm.folder=link
                                                    fm.show()
                                                }
                                            }
                                        }
                                    }
                                }

                                ListModel{
                                    id:recmod
                                    
                                }

                                ScrollView{
                                    anchors.fill: parent
                                    ListView{
                                        id:rlist
                                        delegate:lcomp
                                        model:recmod
                                        clip:true
                                    }
                                    
                                }
                            }
                        }

                        Rectangle{
                            id:racourscis
                            //x:(parent.width/5)+recents.width+100
                            //y:recents.y
                            width:(parent.width/3)+30
                            height:parent.height-10
                            color:parent.color
                            anchors.right:parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 80

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
                                    butt_text:'Alt'
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
                                    butt_text:'Ctrl'
                                    //anchors.verticalCenter: parent.verticalCenter
                                }
                                Text{
                                    x:265
                                    text:'+'
                                    color:'#9B9FA5'
                                    font.pixelSize:14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Butts{
                                    x:285
                                    back_color:parent.color
                                    text_color:'#9B9FA5'
                                    butt_text:'K'
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
        }
    }

    //STATTUS BAR
    Rectangle{
        id: status_bar
        height: 30
        width: parent.width
        anchors.bottom: parent.bottom
        color:'teal'
    }

    //TERMINAL
    Rectangle{
        id:terminal
        height:(parent.height/3)+50
        color:barclaire
        x:leftbar.width+leftbox.width
        width:parent.width-(leftbar.width+leftbox.width)
        border.color:bordercolor
        border.width:1
        anchors.bottom:parent.bottom
        anchors.margins: 30
        visible:false
        clip:true

        UIText{
            anchors.left:parent.left
            anchors.margins: 50
            y:20
            text:'TERMINAL'
            font.pixelSize:15
            color:'white'
        }

        //CLOSER
        Rectangle{
            id:terferm
            width:30
            height:30
            radius:6
            color:parent.color
            anchors.top:parent.top
            anchors.right:parent.right
            anchors.margins: 15
            
            Text{
                id:xx
                anchors.centerIn: parent
                font.pixelSize:16
                color:'white'
                text:qsTr('×')
            }
            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    xx.font.pixelSize=26
                }
                onExited:{
                    xx.font.pixelSize=16
                }
                onClicked:{
                    terminal.visible=false
                }
            }
        }

        //CLOSER
        Rectangle{
            id:xyw
            width:30
            height:30
            //anchors.top:parent.top
            y:terferm.y
            radius:6
            color:parent.color
            anchors.right:parent.right
            anchors.margins: 45
            
            Text{
                id:xxx
                anchors.centerIn: parent
                font.pixelSize:16
                color:'white'
                text:qsTr('^')
            }
            MouseArea{
                anchors.fill: parent
                hoverEnabled:true
                onEntered:{
                    xxx.font.pixelSize=26
                }
                onExited:{
                    xxx.font.pixelSize=16
                }
                onClicked:{
                    if(terminal.height<=(body.height/3)+50){
                        terminal.height=(body.height/2)+150
                    }else{
                        terminal.height=(body.height/3)+50
                    }
                }
            }
        }

        Rectangle{
            y:xyw.height+15
            width:parent.width-2
            height:parent.height-xyw.height-20
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter
            
            Terminal{
                height:parent.height
                width:parent.width
                // anchors.fill: parent
            }
        }

        //RESIZER
        Rectangle{
            width: parent.width
            height: 4
            anchors.top: parent.top
            color:'transparent'
            MouseArea {
                width: parent.width
                height: 4
                anchors.top: parent.top
                anchors.right: parent.right
                cursorShape: Qt.SizeFDiagCursor

                property int startX: 0
                property int startY: 0

                onPressed: {
                    startX = mouseX
                    startY = mouseY
                }
                onPressedChanged: parent.color='transparent'

                // onYChanged: parent.color='teal'

                // onEntered: parent.color='teal'

                onExited: parent.color='transparent'

                onMouseYChanged: {
                    parent.color='teal'
                    if (mouse.buttons === Qt.LeftButton) {
                        var deltaX = mouseX - startX
                        var deltaY = mouseY - startY

                        var newHeight = terminal.height + deltaY

                        terminal.height = Math.abs(Math.max(200, Math.min(newHeight, (root.height*4/5))))

                        startX = mouseX
                        startY = mouseY
                    }
                }
            }
        }
    }

    NumberAnimation{
        id:emu_off
        from: emmubox.x
        to: root.width
        duration: 200
        property: 'x'
        target:emmubox
       
    }
    NumberAnimation{
        id:emu_on
        from: root.width
        to: emmubox.x
        duration: 200
        property: 'x'
        target:emmubox
       
    }

    // EMULATOR BOX
    Rectangle{
        id:emmubox
        width:350
        z:10
        x:root.width
        y:top_bar.height
        height:parent.height-top_bar.height
        color:barclaire
        border.color:bordercolor
        border.width:1
        anchors.right:parent.right
        visible:false

        Rectangle{
            width:parent.width-40
            anchors.top:parent.top
            height:45
            border.width:1
            border.color:bordercolor
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            // RUN BUTTON
            Rectangle{
                height:parent.height-10
                width:35
                radius:7
                color:parent.color
                x:20
                anchors.verticalCenter: parent.verticalCenter
                
                Image{
                    height:20
                    width:20
                    anchors.centerIn: parent
                    source:'../assets/icons/run.png'
                }
                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        // parent.color=hovercolor
                        parent.scale=1.2
                    }
                    onExited:{
                        // parent.color=barclaire
                        parent.scale=1.0
                    }
                    onClicked:{
                        backend.emulator()
                        emloger.running=true
                    }
                }
            }

            //REFRESH BUTTON
            Rectangle{
                height:parent.height-10
                width:35
                radius:7
                color:parent.color
                x:90
                anchors.verticalCenter: parent.verticalCenter
                
                Image{
                    height:20
                    width:20
                    anchors.centerIn: parent
                    source:'../assets/icons/ref.png'
                }
                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        // parent.color=hovercolor
                        parent.scale=1.2
                    }
                    onExited:{
                        // parent.color=barclaire
                        parent.scale=1.0
                    }
                    onClicked:{
                        
                    }
                }
            }

            //HIDE BUTTON
            Rectangle{
                height:parent.height-10
                width:35
                radius:7
                color:parent.color
                x:160
                anchors.verticalCenter: parent.verticalCenter
                
                Image{
                    height:20
                    width:20
                    anchors.centerIn: parent
                    source:'../assets/icons/hide.png'
                }
                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        // parent.color=hovercolor
                        parent.scale=1.2
                    }
                    onExited:{
                        // parent.color=barclaire
                        parent.scale=1.0
                    }
                    onClicked:{
                        emmubox.visible=false
                    }
                }
            }
                
            Rectangle{
                height:parent.height-10
                width:35
                radius:7
                color:parent.color
                x:230
                anchors.verticalCenter: parent.verticalCenter
                
                Image{
                    height:20
                    width:20
                    anchors.centerIn: parent
                    source:'../assets/icons/deco.png'
                    rotation:180
                }
                MouseArea{
                    anchors.fill: parent
                    hoverEnabled:true
                    onEntered:{
                        // parent.color=hovercolor
                        parent.scale=1.2
                    }
                    onExited:{
                        // parent.color=barclaire
                        parent.scale=1.0
                    }
                    onClicked:{
                        
                    }
                }
            }
        }
        
        Rectangle{
            width:350-20
            height:parent.height-47
            y:46
            color:parent.color
            anchors.horizontalCenter: parent.horizontalCenter

            Image{
                width:parent.width
                height:parent.height
                source:'../assets/images/em.png'
                visible:false
            }
            Column{
                anchors.fill:parent
                anchors.margins:5
                spacing:10
                Rectangle{
                    color:parent.parent.color
                    height: 40
                    width: parent.width
                    Text{
                        text:'Events Log'
                        color:'#FFFFFF'
                        font.pixelSize:16
                        anchors.centerIn:parent
                    }
                }
                Rectangle{
                    height: parent.height-50
                    width:parent.width
                    color:appcolor

                    Timer{
                        id:emloger
                        running:false
                        interval:5000
                        repeat:true
                        onTriggered:{
                            logmod.clear()
                            logmod.append(JSON.parse(obj.reparse(backend.emulationLog())))
                            loglist.positionViewAtEnd()
                        }
                    }
                    
                    //Component.onCompleted: backend.logEvent.connect(root.onLogEvent())

                    Component{
                        id:logdeg
                        Rectangle{
                            height: childrenRect.height+20//mlg.height+20
                            width: loglist.width
                            color:moyen
                            border.width:1
                            border.color:bordercolor
                            Row{
                                anchors.fill:parent
                                spacing: 10
                                anchors.margins:2
                                Rectangle{
                                    height: parent.height-20
                                    width: height
                                    color:parent.parent.color
                                    anchors.verticalCenter:parent.verticalCenter
                                    Image{
                                        anchors.fill:parent
                                        source:''
                                    }
                                }
                                Rectangle{
                                    height: childrenRect.height
                                    width: parent.width-50
                                    color:moyen
                                    anchors.verticalCenter:parent.verticalCenter
                                    Text{
                                        id:mlg
                                        text: msg
                                        color:'#CCCCCC'
                                        font.pixelSize:10
                                        wrapMode: Text.WordWrap
                                        width:parent.width
                                        height: parent.height
                                        lineHeight: 15
                                        anchors.verticalCenter:parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                    ListModel{
                        id:logmod
                    }

                    ScrollView{
                        anchors.fill:parent
                        ListView{
                            id:loglist
                            anchors.fill:parent
                            spacing:5
                            clip:true
                            model:logmod
                            delegate: logdeg
                        }
                    }
                }
            }
        }
    }

    Component{
        id:codebox
        Rectangle{
            color:root.color
            property alias furl:nfc.link
            property alias codealias:nfc.code
            CodeEditor{
                id:nfc
                compcolor:barclaire
                edit_height:parent.height
                edit_width:parent.width
                anchors.fill: parent
                //code:''
                
            }
            Component.onCompleted:{
                nfc.link=lnk
            }
            // Shortcut {
            //     sequence: "Ctrl+S"
            //     onActivated: {
            //         console.log('saving file...')
            //         cde=nfc.scode.getText(0,nfc.code.length)
            //         //console.log(cde)
            //         backend.savefile(fm.folder.toString(),codetab.getTab(codetab.currentIndex).title,cde)
            //         //cde=''
            //     }
            // }
        }
    }

    Component{
        id:cb
        Rectangle{
            color:root.color
            width:codetab.width
            height:codetab.height
            property alias cd:ce.scode
            property alias lk:ce.link
            CodeEditor{
                id:ce
                compcolor:barclaire
                edit_height:parent.height
                edit_width:parent.width
                anchors.fill: parent
                //code:text
            }
            Component.onCompleted:{
                ce.code=qsTr(cde).replace('\n\r',qsTr('\n'))
                ce.link=lnk
                //console.log(ce.link)
            }
            
        }
    }

    FileOpenDialog{
        id:fileop
        anchors.centerIn: parent
        visible:false
        theme_color:barclaire
        border_color:bordercolor
        Keys.onReturnPressed:{
            visible=false
            if(root.currentFolder==''){
                root.currentFolder=fm.folder
            }
            backend.newfile(fileop.get_filename,root.currentFolder.toString())
            lnk=root.currentFolder.toString()+fileop.get_filename.toString()
            codetab.insertTab(codetab.currentIndex+1,fileop.get_filename,codebox)
        }
    }
    FileOpenDialog{
        id:foldn
        anchors.centerIn: parent
        visible:false
        theme_color:barclaire
        border_color:bordercolor
        message:'Create new folder'
        field.placeholderText:'foldername'
        Keys.onReturnPressed:{
            visible=false
            //console.log()
            backend.newfolder(foldn.get_filename,root.currentFolder.toString())
            //codetab.addTab(fileop.get_filename,cb)
        }
    }

    FileDialog{
        id:opfile
        defaultSuffix: '*.py'
        //fileUrl: url
        //fileUrls: list<url>
        folder: shortcuts.home
        //modality: Qt: : WindowModality
        nameFilters: ["All files (*)"]
        selectExisting: true
        selectFolder: false
        selectMultiple: false
        //selectedNameFilter: string
        //shortcuts: Object
        //sidebarVisible: bool
        title: 'Open file'
        //visible: bool
        onAccepted:{
            var text=backend.openfile(fileUrl)
            var titre=backend.get_filename(fileUrl)
            cde=text
            lnk=fileUrl.toString()
            codetab.insertTab(codetab.currentIndex+1, titre,cb)
            //root.setcode(text)
        }
    }
    FileDialog{
        id:opfold
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
        //sidebarVisible: bool
        title: 'Open folder'
        //visible: bool
        onAccepted:{
            var text=opfold.fileUrl
            //console.log(text.toString())//.substr(6,text.length-6))
            //tmod.clear()
            fm.folder=text.toString()//.substr(6,text.length-6)
            fm.show()
            FileManagerBackend.save_to_history(text)
        }
    }

    FileDialog{
        id:plugdialog
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
        title: 'Choose Plugin folder to install'
        //visible: bool
        onAccepted:{
            var text=fileUrl
            //console.log(text.toString())//.substr(6,text.length-6))
            loading.visible=true
            timer.running=true
            var r=backend.installPlugin(text);
        }
    }
    Timer{
        id: timer
        running: false
        repeat: false
        interval:3000

        onTriggered: loading.visible=false;
    }

    Rectangle{
        id:loading
        height:110
        width:320
        border.width:1
        border.color:bordercolor
        color:barclaire
        anchors.centerIn:parent
        visible:false
        property string msgt:'please wait until the installation'
        Row{
            anchors.fill:parent
            anchors.margins:10
            spacing:15
            Rectangle{
                color:parent.parent.color
                height:parent.height
                width:height//(parent.parent.width/4)-15
                anchors.verticalCenter: parent.verticalCenter
                AnimatedImage{
                    anchors.fill:parent
                    source:'../assets/images/load.gif'
                }
            }
            Rectangle{
                color:parent.parent.color
                height:parent.height
                width:parent.width-height-15//((parent.width*3)/4)-15
                anchors.verticalCenter: parent.verticalCenter
                
                Text{
                    id:insmsg
                    text:loading.msgt
                    color:'white'
                    font.pointSize:10
                    anchors.centerIn:parent
                }
            }
        }
    }

    // NOTIFICATION WIDGET
    Rectangle{
        id:notification
        width:350
        height:childrenRect.height
        anchors.right:parent.right
        anchors.bottom:parent.bottom
        anchors.margins: 35
        color:appcolor
        visible:false
        border{
            width:1
            color:'#EEEEEE'
        }

        Rectangle{
            height:10
            width:10
        }
    }

    Dialog{
        id:newproj
        height: 450
        width: 700
        title: 'new project'
        contentItem:NewProject{
            anchors.fill:parent
            onCanceled:{
                newproj.close()
            }
            onCreated:{
                
                root.openProject('file://'+path)
            }
        }
        standardButtons: StandardButton.Cancel| StandardButton.Ok
    }
}
