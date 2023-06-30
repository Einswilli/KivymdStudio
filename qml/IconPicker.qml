import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
//import '../Js/highlightcolor.js' as Logic
// import '../Js/prism.js' as PrismJS

Item{
    id:root
    anchors.fill:parent
    property var icons_
    property var icons_list:[]

    //SIGNALS
    signal iconSelected(string name)

    Connections{
        enabled:true
        target:backend
        ignoreUnknownSignals: false
    }

    
    Component.onCompleted: {
        root.icons_=icons//JSON.parse(backend.load_icons())
        initial_icons()
    }

    function initial_icons(){
        var dict={}
        // var list=[]
        model_.clear()
        for(const key in root.icons_){
            dict['name']=key
            dict['value']=root.icons_[key]
            root.icons_list.push(dict)
            model_.append(dict)
        }
            // console.log(JSON.stringify(root.icons_list))
    }

    function search(text){
        // var filteredlist=[]
        var dict={}
        model_.clear()
        for(const key in root.icons_){
            if(key.includes(text)){
                dict['name']=key
                dict['value']=root.icons_[key]
                // filteredlist.push(dict)
                //add it to the model
                model_.append(dict)
            }
        }
        
    }

    Rectangle{
        anchors.fill:parent
        color:'transparent'

        Column{
            anchors.fill:parent
            spacing:10
            anchors.margins: 5
            
            Rectangle{
                id:input
                height: 50
                width:parent.width
                color:'transparent'

                Input{
                    id:searchinput
                    h:parent.height
                    w:parent.width
                    rad:8
                    backcolor:'#292828'
                    plhc:'#CCCCCC'
                    plhtext:'search for icons...'

                    onTxtChanged:{
                        root.search(txt)
                    }
                }
            }

            Rectangle{
                id:list
                height: parent.height-60
                width: parent.width
                color:'transparent'

                Component{
                    id:delegate_
                    Rectangle{
                        height:grid.cellHeight-6
                        width:grid.cellWidth-6
                        radius:8
                        color:'#292828'

                        Rectangle{
                            height:parent.height
                            width:height
                            color:'transparent'
                            anchors.verticalCenter: parent.verticalCenter

                            TextIcon{
                                id:ico_
                                _size:17
                                text: icons[name]
                                anchors.fill: parent
                                color:'#AAAAAA'
                            }
                        }

                        MouseArea{
                            hoverEnabled:true
                            anchors.fill:parent

                            onEntered:{
                                parent.color='#18191A'
                            }

                            onExited:{
                                parent.color='#292828'
                            }

                            onClicked:{
                                root.iconSelected(name)
                            }
                        }
                    }
                }

                ListModel{
                    id:model_
                }

                ScrollView{
                    anchors.fill:parent
                    clip:true

                    GridView{
                        id:grid
                        cellWidth:72
                        cellHeight:72
                        delegate:delegate_
                        model:model_
                        anchors.fill:parent
                    }
                }
            }
        }
    }
}