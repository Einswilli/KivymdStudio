import QtQuick 2.15
import QtQuick.Window 2.15

Item {
    id: root

    property string icon: "folder"
    property color color: "#CCCCCC"
    property int size: 20
    property var customPaths: ({})
    property bool smooth: true

    implicitWidth: size
    implicitHeight: size

    readonly property string _customSource: IconRegistry.customSource(root.icon, root.customPaths)
    readonly property string _glyph: IconRegistry.glyph(root.icon)
    readonly property bool _isImage: _customSource.length > 0

    Image {
        id: imageIcon
        anchors.centerIn: parent
        width: root.size
        height: root.size
        sourceSize.width: root.size * root.screenDevicePixelRatio
        sourceSize.height: root.size * root.screenDevicePixelRatio
        source: root._isImage ? root._customSource : ""
        visible: root._isImage
        asynchronous: true
        smooth: root.smooth
        mipmap: true
    }

    Text {
        id: fontIcon
        anchors.centerIn: parent
        text: root._glyph.length > 0 ? root._glyph : IconRegistry.glyph("file-outline")
        visible: !root._isImage
        color: root.color
        font.family: IconRegistry.fontFamily
        font.pixelSize: root.size
        lineHeight: 1
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }

    readonly property real screenDevicePixelRatio: {
        if (typeof Screen !== "undefined") return Screen.devicePixelRatio
        return 1
    }
}
