/*
    Copyright (C) 2011 Jocelyn Turcotte <turcotte.j@gmail.com>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this program; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0

Rectangle {
    id: container

    // --- properties
    property QtObject model: undefined
    property Item delegate
    // property alias suggestionsModel: filterItem.model
    property string ifilter: ''//filterItem.filter
    property string modeIndicator:''
    property string code:''
    property int line
    property int pos
    // property alias property: filterItem.property
    signal itemSelected(variant item)


    // --- behaviours
    z: parent.z + 100
    visible: false//filter.length > 0 && suggestionsModel.count > 0
    height: visible ? childrenRect.height : 0
    Behavior on height {
        SpringAnimation { spring: 2; damping: 0.2 }
    }

    Connections {
        // onFilterChanged: invalidateFilter()
        // onPropertyChanged: invalidateFilter()
        // onSourceModelChanged: invalidateFilter()
        function onIfilterChanged(){
            lmod.clear()
            lmod.append(JSON.parse(EditorManager.filter(ifilter,modeIndicator,code,line,pos)))
            if (lmod.length==0){
                var d={'name':'No Suggestions','text':'','doc':''}
                lmod.append(d)
            }
        }
    }
    Component.onCompleted: lmod.append(JSON.parse(EditorManager.filter(' ',' ',' ',0,0)))


    // --- defaults
    color: '#292828'
    radius: 0
    border {
        width: 1
        color: '#2E2F30'
    }


    // Filter {
    //     id: filterItem
    //     //sourceModel: container.model
    //     filter:container.ifilter
    // }

    ListModel{
        id:lmod
    }

    // --- UI
    // Rectangle{
    //     height: 300
    //     width: parent.width
    //     color:parent.color
    //     visible: parent.visible
    //     clip:true
    //     ScrollView{
    //         // width: parent.width
    //         // height: parent.visible?300:0
    //         anchors.fill:parent
    //         visible: false//parent.visible
        ScrollView{
            height: Math.min(250,popup.childrenRect.height)
            width: parent.width
            clip:true
            Column {
                id: popup
                clip: true
                height: childrenRect.height
                width: parent.width - 6
                anchors.centerIn: parent


                property int selectedIndex
                property variant selectedItem: selectedIndex == -1 ? null : model[selectedIndex]
                signal suggestionClicked(variant suggestion)

                opacity: container.visible ? 1.0 : 0
                Behavior on opacity {
                    NumberAnimation { }
                }


                Repeater {
                    id: repeater
                    model: lmod//filterItem.model//container.suggestionsModel
                    delegate: Rectangle {
                        id: delegateItem
                        property variant suggestion: model

                        height: textComponent.height+10
                        width: container.width-5
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: '#292828'
                        border {
                            width: 1
                            color: '#2E2F30'
                        }

                        Text {
                            id: textComponent
                            color: "white"
                            text: suggestion.name
                            textFormat: TextEdit.RichText
                            width: parent.width - 6
                            font.pointSize:11
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Image{
                            height: parent.height
                            width:height
                            source: '../assets/icons/File.svg'
                            anchors.right:parent.right
                            anchors.margins:5
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                parent.color='#2E2F30'
                            }
                            onExited: {
                                parent.color='#292828'
                            }
                            onClicked: {
                                if(delegateItem.suggestion.text!=''){
                                    container.itemSelected(delegateItem.suggestion)
                                    container.visible=false
                                }
                            }
                        }
                    }
                }
            }
        }
}

