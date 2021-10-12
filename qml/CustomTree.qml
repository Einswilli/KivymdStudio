import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
import QtQuick.Dialogs 1.2
import Qt.labs.folderlistmodel 2.15
import QtQml.Models 2.2

Item {
    id:root
    width: 200
    height: 300

    function addchild(data){

        var sub=[]
        var i=0
        var r=data[0]
        for (var n in data){
            f=n.match(/[a-zA-Z0-9_.\s/]*/)
            if (n.substr(-1,1)=='/'){
                i+=1
                //var catName=f.substr(0,f.length-1)
            }else{
                // lst.model=ficmod
                // ficmod.append({'itemName':n})
                break
            }
        }
        for(var i of ){
            sub[i]=anObject[prop][i]
        }
        nestedModel.append ({"categoryName" : prop, collapsed: true, "subItems": sub, collapsed:true});
    }

    // signal datadding(data)
    // onDatadding:addchild()
    ScrollView{
        anchors.fill: parent
        ListView {
            id:lst
            anchors.fill: parent
            model: nestedModel
            delegate: categoryDelegate
        }
    }

    ListModel {
        id: nestedModel
        ListElement {
            categoryName: 'doc'
            collapsed: true

            // A ListElement can't contain child elements, but it can contain
            // a list of elements. A list of ListElements can be used as a model
            // just like any other model type.
            subItems: [
                ListElement { itemName: "Tomato" },
                ListElement { itemName: "Cucumber" },
                ListElement { itemName: "Onion" },
                ListElement { itemName: "Brains" }
            ]
        }

        ListElement {
            categoryName: "Fruits"
            collapsed: true
            subItems: [
                ListElement { itemName: "Orange" },
                ListElement { itemName: "Apple" },
                ListElement { itemName: "Pear" },
                ListElement { itemName: "Lemon" }
            ]
        }

        ListElement {
            categoryName: "Cars"
            collapsed: true
            subItems: [
                ListElement { itemName: "Nissan" },
                ListElement { itemName: "Toyota" },
                ListElement { itemName: "Chevy" },
                ListElement { itemName: "Audi" }
            ]
        }
    }

    Component {
        id: categoryDelegate
        Column {
            width: 200

            Rectangle {
                id: categoryItem
                border.color: "black"
                border.width: 1
                color: "#535252"
                height: 30
                width: 150

                Text {
                    id:ct
                    anchors.verticalCenter: parent.verticalCenter
                    x: 40
                    font.pixelSize: 16
                    text: categoryName
                    color:'white'
                }

                Rectangle {
                    color: "#404247"
                    width: 22
                    height: 22
                    radius:30
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent

                        // Toggle the 'collapsed' property
                        onClicked:{
                            
                            nestedModel.setProperty(index, "collapsed", !collapsed)
                        }
                    }
                }
            }

            Loader {
                id: subItemLoader

                // This is a workaround for a bug/feature in the Loader element. If sourceComponent is set to null
                // the Loader element retains the same height it had when sourceComponent was set. Setting visible
                // to false makes the parent Column treat it as if it's height was 0.
                visible: !collapsed
                property variant subItemModel : subItems
                sourceComponent: collapsed ? null : subItemColumnDelegate
                onStatusChanged: if (status == Loader.Ready) item.model = subItemModel
            }
        }

    }

    Component {
        id: subItemColumnDelegate
        Column {
            property alias model : subItemRepeater.model
            width: 170
            x:30
            Repeater {
                id: subItemRepeater
                delegate: Rectangle {
                    color: "#6C6D6E"
                    height: 30
                    width: 140
                    border.color: "#CACBCC"
                    border.width: 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 30
                        font.pixelSize: 13
                        text: itemName
                        color:'white'
                    }
                }
            }
        }
    }

    Component {
        id: ficmod
        Column {
            property alias model : ficItemRepeater.model
            width: 170
            x:30
            Repeater {
                id: ficItemRepeater
                delegate: Rectangle {
                    color: "#6C6D6E"
                    height: 30
                    width: 140
                    border.color: "#CACBCC"
                    border.width: 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 30
                        font.pixelSize: 13
                        text: itemName
                        color:'white'
                    }
                }
            }
        }
    }
}