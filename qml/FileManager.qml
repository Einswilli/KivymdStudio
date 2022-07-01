/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the Qt Mobility Components.
**
** $QT_BEGIN_LICENSE:BSD$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** BSD License Usage
** Alternatively, you may use this file under the terms of the BSD license
** as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/


import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
import QtQuick.Dialogs 1.2
import Qt.labs.folderlistmodel 2.15
import QtQml.Models 2.2

Rectangle {
    id: fileBrowser
    color: "transparent"
    z: 4

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

    property string folder
    property bool shown: loader.sourceComponent
    property int itemHeight:30
    property int itemWidth:30
    property int scaledMargin:7
    property alias bscolor:fileBrowser.color
    property string sfile
    property string currfold:folders.folder

    signal fileSelected(string file)
    //signal 

    function selectFile(file) {
        if (file !== "") {
            folder = loader.item.folders.folder
            fileBrowser.fileSelected(file)
            //sfile=file
        }
        //loader.sourceComponent = undefined
    }
    function getselectedfile(){
        return sfile.toString()
    }
    //onFileSelected:fileBrowser.getselectedfile()

    Loader {
        id: loader
    }

    function show() {
        loader.sourceComponent = fileBrowserComponent
        loader.item.parent = fileBrowser
        loader.item.anchors.fill = fileBrowser
        loader.item.folder = fileBrowser.folder
    }

    Component {
        id: fileBrowserComponent

        Rectangle {
            id: root
            color: "transparent"
            property bool showFocusHighlight: false
            property variant folders: folders1
            property variant view: view1
            property alias folder: folders1.folder
            property color textColor: "white"

            FolderListModel {
                id: folders1
                folder: folder
            }

            FolderListModel {
                id: folders2
                folder: folder
            }

            SystemPalette {
                id: palette
            }

            Component {
                id: folderDelegate

                Rectangle {
                    id: wrapper
                    function launch() {
                        var path = "file://";
                        if (filePath.length > 2 && filePath[1] === ':') // Windows drive logic, see QUrl::fromLocalFile()
                            path += '/';
                        path += filePath;
                        if (folders.isFolder(index))
                            down(path);
                        else
                            fileBrowser.selectFile(path)
                            sfile=fileName
                    }
                    width: root.width
                    height: itemHeight
                    color: "transparent"

                    Rectangle {
                        id: highlight; visible: false
                        anchors.fill: parent
                        color: palette.highlight
                        gradient: Gradient {
                            GradientStop { id: t1; position: 0.0; color: palette.highlight }
                            GradientStop { id: t2; position: 1.0; color: Qt.lighter(palette.highlight) }
                        }
                    }

                    Item {
                        width: itemHeight; height: itemHeight
                        Image {
                            id:img
                            source: "../assets/icons/fold.png"
                            fillMode: Image.PreserveAspectFit
                            anchors.fill: parent
                            anchors.margins: scaledMargin
                            //visible: folders.isFolder(index)
                        }
                        Component.onCompleted:{
                            if(folders.isFolder(index)){
                                if (fileName=='__pycache__'){
                                    img.source="../assets/icons/pyf.svg"
                                }else if(fileName=='js'||fileName=='Js'||fileName=='JS'){
                                    img.source="../assets/icons/jsf.svg"
                                }else if(fileName=='icons'||fileName=='Icons'||fileName=='Images'||fileName=='images'||fileName=='screenshots'||fileName=='photos'||fileName=='Screenshots'||fileName=='Photos'){
                                    img.source="../assets/icons/imf.svg"
                                }else{
                                    img.source="../assets/icons/fold.png"
                                }
                            }
                            else if (fileName.toString().substr(-3,3)=='.py'){
                                img.source="../assets/images/py.png"
                            }else if (fileName.substr(-3,3)=='.kv'){
                                img.source="../assets/images/kv.png"
                            }else if (fileName.substr(-3,3)=='.js'){
                                img.source="../assets/images/js.png"
                            }else if (fileName.substr(-3,3)=='cpp'){
                                img.source="../assets/images/cpp.png"
                            }else if (fileName.substr(-3,3)=='.db'){
                                img.source="../assets/icons/db.png"
                            }else if (fileName.substr(-3,3)=='.md'){
                                img.source="../assets/images/md.png"
                            }else if (fileName.substr(-4,4)=='.qml'){
                                img.source="../assets/icons/qml.svg"
                            }else if (fileName.substr(-4,4)=='.png'){
                                img.source="../assets/icons/ima.svg"
                            }else if (fileName.substr(-4,4)=='.jpg'){
                                img.source="../assets/icons/ima.svg"
                            }else if (fileName.substr(-5,5)=='.webp'){
                                img.source="../assets/icons/im.svg"
                            }else if (fileName.substr(-5,5)=='.jpeg'){
                                img.source="../assets/icons/im.svg"
                            }else if (fileName.substr(-4,4)=='.svg'){
                                img.source="../assets/icons/sv.svg"
                            }else if (fileName.substr(-4,4)=='.txt'){
                                img.source="../assets/icons/txt.svg"
                            }else if (fileName.substr(-4,4)=='.php'){
                                img.source="../assets/icons/php.svg"
                            }else if (fileName.substr(-4,4)=='.pyc'){
                                img.source="../assets/icons/cyt.svg"
                            }else if (fileName.substr(-2,2)=='.h'){
                                img.source="../assets/icons/h.svg"
                            }else if (fileName.substr(-4,4)=='.psd'){
                                img.source="../assets/icons/psd.svg"
                            }else if (fileName.substr(-4,4)=='.ttf'){
                                img.source="../assets/icons/font.svg"
                            }else if (fileName.substr(-7,7)=='.sqlite'){
                                img.source="../assets/icons/sq.svg"
                            }else if (fileName.substr(-8,8)=='.sqlite3'){
                                img.source="../assets/icons/sq.svg"
                            }else{
                                img.source="../assets/icons/sf.svg"
                            }
                            
                        }
                    }

                    Text {
                        id: nameText
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: fileName
                        anchors.leftMargin: img.width+15
                        font.pixelSize: 14
                        color: (wrapper.ListView.isCurrentItem && root.showFocusHighlight) ? palette.highlightedText : textColor
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: mouseRegion
                        anchors.fill: parent
                        onPressed: {
                            root.showFocusHighlight = false;
                            wrapper.ListView.view.currentIndex = index;
                        }
                        onClicked: { if (folders == wrapper.ListView.view.model) launch() }
                        onEntered:{
                            wrapper.color='#1D313D9C';
                        }
                        onExited:{
                            wrapper.color='transparent'
                        }
                    }

                    states: [
                        State {
                            name: "pressed"
                            when: mouseRegion.pressed
                            PropertyChanges { target: highlight; visible: true }
                            PropertyChanges { target: nameText; color: palette.highlightedText }
                        }
                    ]
                }
            }

            ListView {
                id: view1
                anchors.top: titleBar.bottom
                anchors.bottom: parent.bottom
                x: 0
                width: parent.width
                model: folders1
                delegate: folderDelegate
                highlight: Rectangle {
                    color: palette.highlight
                    visible: root.showFocusHighlight && view1.count != 0
                    gradient: Gradient {
                        GradientStop { id: t1; position: 0.0; color: palette.highlight }
                        GradientStop { id: t2; position: 1.0; color: Qt.lighter(palette.highlight) }
                    }
                    width: view1.currentItem == null ? 0 : view1.currentItem.width
                }
                highlightMoveVelocity: 1000
                pressDelay: 100
                focus: true
                state: "current"
                states: [
                    State {
                        name: "current"
                        PropertyChanges { target: view1; x: 0 }
                    },
                    State {
                        name: "exitLeft"
                        PropertyChanges { target: view1; x: -root.width-100 }
                    },
                    State {
                        name: "exitRight"
                        PropertyChanges { target: view1; x: root.width }
                    }
                ]
                transitions: [
                    Transition {
                        to: "current"
                        SequentialAnimation {
                            NumberAnimation { properties: "x"; duration: 250 }
                        }
                    },
                    Transition {
                        NumberAnimation { properties: "x"; duration: 250 }
                        NumberAnimation { properties: "x"; duration: 250 }
                    }
                ]
                Keys.onPressed: root.keyPressed(event.key)
            }

            ListView {
                id: view2
                anchors.top: titleBar.bottom
                anchors.bottom: parent.bottom
                x: parent.width
                width: parent.width
                model: folders2
                delegate: folderDelegate
                highlight: Rectangle {
                    color: palette.highlight
                    visible: root.showFocusHighlight && view2.count != 0
                    gradient: Gradient {
                        GradientStop { id: t1; position: 0.0; color: palette.highlight }
                        GradientStop { id: t2; position: 1.0; color: Qt.lighter(palette.highlight) }
                    }
                    width: view1.currentItem == null ? 0 : view1.currentItem.width
                }
                highlightMoveVelocity: 1000
                pressDelay: 100
                states: [
                    State {
                        name: "current"
                        PropertyChanges { target: view2; x: 0 }
                    },
                    State {
                        name: "exitLeft"
                        PropertyChanges { target: view2; x: -root.width-100 }
                    },
                    State {
                        name: "exitRight"
                        PropertyChanges { target: view2; x: root.width }
                    }
                ]
                transitions: [
                    Transition {
                        to: "current"
                        SequentialAnimation {
                            NumberAnimation { properties: "x"; duration: 250 }
                        }
                    },
                    Transition {
                        NumberAnimation { properties: "x"; duration: 250 }
                    }
                ]
                Keys.onPressed: root.keyPressed(event.key)
            }

            // Button {
            //     id: cancelButton
            //     width: itemWidth
            //     height: itemHeight
            //     background:Rectangle{
            //             color: "#353535"
            //             anchors.fill: parent
            //         }
            //     anchors { bottom: parent.bottom; right: parent.right; margins: 5 * scaledMargin }
            //     text: "Cancel"
            //     //horizontalAlign: Text.AlignHCenter
            //     onClicked: fileBrowser.selectFile("")
            // }

            Keys.onPressed: {
                root.keyPressed(event.key);
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Select || event.key === Qt.Key_Right) {
                    view.currentItem.launch();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    up();
                }
            }

            // titlebar
            Rectangle {
                color: "transparent"
                width: parent.width;
                height: itemHeight
                id: titleBar

                Rectangle {
                    id: upButton
                    width: titleBar.height
                    height: titleBar.height
                    color: "transparent"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: scaledMargin

                    Image { anchors.fill: parent; anchors.margins: scaledMargin; source: "../assets/icons/deco.png" }
                    MouseArea { id: upRegion; anchors.fill: parent; onClicked: up() }
                    states: [
                        State {
                            name: "pressed"
                            when: upRegion.pressed
                            PropertyChanges { target: upButton; color: palette.highlight }
                        }
                    ]
                }

                Text {
                    id:fldrs
                    anchors.left: upButton.right; anchors.right: parent.right; height: parent.height
                    anchors.leftMargin: 10; anchors.rightMargin: 4
                    text: folders.folder
                    color: "white"
                    elide: Text.ElideLeft; horizontalAlignment: Text.AlignLeft; verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
            }

            Rectangle {
                color: "#353535"
                width: parent.width
                height: 1
                anchors.top: titleBar.bottom
            }

            function down(path) {
                if (folders == folders1) {
                    view = view2
                    folders = folders2;
                    view1.state = "exitLeft";
                } else {
                    view = view1
                    folders = folders1;
                    view2.state = "exitLeft";
                }
                view.x = root.width;
                view.state = "current";
                view.focus = true;
                folders.folder = path;
            }

            function up() {
                var path = folders.parentFolder;
                if (path.toString().length === 0 || path.toString() === 'file:')
                    return;
                if (folders == folders1) {
                    view = view2
                    folders = folders2;
                    view1.state = "exitRight";
                } else {
                    view = view1
                    folders = folders1;
                    view2.state = "exitRight";
                }
                view.x = -root.width;
                view.state = "current";
                view.focus = true;
                folders.folder = path;
            }

            function keyPressed(key) {
                switch (key) {
                    case Qt.Key_Up:
                    case Qt.Key_Down:
                    case Qt.Key_Left:
                    case Qt.Key_Right:
                        root.showFocusHighlight = true;
                    break;
                    default:
                        // do nothing
                    break;
                }
            }
        }
    }
}