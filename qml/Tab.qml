import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import QtCharts 2.15
import QtQuick.Layouts 1.0
//import Qt5Compat.GraphicalEffects

Loader{
    id:tab
    anchors.fill: parent
    property string title
    property bool __inserted:false

    Accessible.role: Accessible.LayeredPane
    active:false
    visible:false

    activeFocusOnTab:false
    onVisibleChanged: if (visible) active=true
    
    default property alias component: tab.sourceComponent
    
}