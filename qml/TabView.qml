import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

/*
 * TabView — Qt6-compatible tab container.
 *
 * Uses TabBar + dynamically managed content area.
 * API: insertTab(index, title, component), removeTab(index), getTab(index),
 *       currentIndex, indexOf(title), contains(title)
 */

FocusScope {
    id: root

    property int currentIndex: 0
    property int count: tabBar.count
    property var tabs: []

    signal tabClosed(int index)

    implicitWidth: 400
    implicitHeight: 300

    Component.onCompleted: {
        tabs = []
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            onCurrentIndexChanged: {
                root.currentIndex = currentIndex
            }
        }

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }
    }

    function _showTab(index) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i] && tabs[i].loader) {
                tabs[i].loader.visible = (i === index)
            }
        }
        if (index >= 0 && index < tabBar.count) {
            tabBar.currentIndex = index
        }
    }

    function insertTab(index, title, component) {
        if (component === undefined) return

        var idx = Math.min(index, tabBar.count)

        var tabBtn = Qt.createQmlObject(
            'import QtQuick.Controls 2.15; TabButton { text: "' + title.replace(/"/g, '\\"') + '" }',
            tabBar
        )
        tabBar.insertItem(idx, tabBtn)

        var loaderComp = Qt.createComponent("qrc:/qt-project.org/imports/QtQuick/Controls/Basic/Loader") 
        // Fallback: use inline Loader
        var loader = Qt.createQmlObject(
            'import QtQuick 2.15; Loader { anchors.fill: parent; visible: false }',
            contentArea
        )
        loader.sourceComponent = component

        tabs.splice(idx, 0, { title: title, loader: loader, button: tabBtn })
        _showTab(idx)
    }

    function addTab(title, component) {
        insertTab(tabBar.count, title, component)
    }

    function removeTab(index) {
        if (index < 0 || index >= tabs.length) return

        var entry = tabs[index]
        if (entry.loader) entry.loader.destroy()
        if (entry.button) entry.button.destroy()
        tabBar.removeItem(index)
        tabs.splice(index, 1)

        root.tabClosed(index)
        var newIdx = Math.min(root.currentIndex, tabs.length - 1)
        if (newIdx >= 0) {
            _showTab(newIdx)
        }
    }

    function remove(index) { removeTab(index) }

    function getTab(index) {
        if (index < 0 || index >= tabs.length) return null
        var entry = tabs[index]
        return {
            title: entry.title,
            item: entry.loader ? entry.loader.item : null,
        }
    }

    function indexOf(title) {
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].title === title) return i
        }
        return -1
    }

    function contains(title) {
        return indexOf(title) >= 0
    }

    function rmTab(index) { removeTab(index) }
}
