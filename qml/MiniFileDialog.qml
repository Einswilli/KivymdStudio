/*========================================================================
  OpenView -- http://openview.kitware.com
  Copyright 2012 Kitware, Inc.
  Licensed under the BSD license. See LICENSE file for details.
 ========================================================================*/
import QtQuick 2.0
import Qt.labs.folderlistmodel 1.0

Rectangle {
  signal fileSelected (string filePath, string fileName)

  ListView {
    anchors.fill: parent

    FolderListModel {
      id: foldermodel
      folder: "file:///"
      nameFilters: ["*.*"]
      showDotAndDotDot: true
    }

    Component {
      id: filedelegate
      Rectangle {
        width: parent.width
        height: 40

        gradient: Gradient {
          GradientStop { position: 0.0; color: "#fff" }
          GradientStop { position: 1.0; color: "#eee" }
        }

        Image {
          source: foldermodel.isFolder(index) ? "folder.png" : "file.png";
          x: 10;
          anchors.verticalCenter: parent.verticalCenter;
        }

        UIText {
          text: fileName;
          elide: Text.ElideMiddle;
          anchors.fill: parent
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 30
          anchors.rightMargin: 10
          verticalAlignment: Text.AlignVCenter
          MouseArea {
            anchors.fill: parent
            onClicked: {
              if (foldermodel.isFolder(index)) {
                var fixedPath = "";
                if (filePath === "/..") {
                  fixedPath = "/";
                } else if (filePath.substring(filePath.length - 3) === "/..") {
                  var parts = filePath.split("/");
                  fixedPath = "";
                  for (var i = 1; i < parts.length - 2; ++i) {
                    fixedPath += "/" + parts[i];
                  }
                  if (fixedPath === "") {
                    fixedPath = "/";
                  }
                } else {
                  fixedPath = filePath;
                }
                foldermodel.folder = "file://" + fixedPath;
              }
              else {
                fileSelected("file://" + filePath, fileName)
              }
            }
          }
        }
      }
    }

    model: foldermodel
    delegate: filedelegate
    header: Rectangle {
      height: 40;
      width: 200;
      color: "#444";
      UIText {
        text: foldermodel.folder.toString().substring(7)
        anchors.fill: parent
        elide: Text.ElideMiddle;
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        color: "white";
      }
    }
  }
}