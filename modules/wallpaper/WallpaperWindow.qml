import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    required property QtObject config
    required property var screenRef

    screen: screenRef

    anchors { top: true; bottom: true; left: true; right: true }

    exclusionMode: ExclusionMode.Ignore

    focusable: false
    color: "transparent"
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "m4.shell:wallpaper"

    readonly property string sourcePath: (config && config.wallpapers) ? config.wallpapers.current : ""
    readonly property int reloadSerial: (config && config.wallpapers) ? config.wallpapers.reloadSerial : 0

    function toFileUrlWithBust(p, serial) {
        if (!p) return ""
        const url = p.startsWith("file://") ? p : ("file://" + p)
        return url + "?v=" + serial
    }

    Rectangle {
        anchors.fill: parent
        color: (config && config.appearance && config.appearance.bg2 !== undefined)
            ? config.appearance.bg2
            : "#141414"
    }

    property Item currentImg: imgA

    function applySource() {
        if (!sourcePath) {
            currentImg = null
            imgA.source = ""
            imgB.source = ""
            return
        }

        const s = toFileUrlWithBust(sourcePath, reloadSerial)

        if (currentImg === imgA)
            imgB.source = s
        else
            imgA.source = s
    }

    onSourcePathChanged: applySource()
    onReloadSerialChanged: applySource()

    Component.onCompleted: {
        if (sourcePath)
            imgA.source = toFileUrlWithBust(sourcePath, reloadSerial)
    }

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: (root.currentImg === imgA) ? 1 : 0

        onStatusChanged: {
            if (status === Image.Ready)
                root.currentImg = imgA
        }

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.InOutCubic }
        }
    }

    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: (root.currentImg === imgB) ? 1 : 0

        onStatusChanged: {
            if (status === Image.Ready)
                root.currentImg = imgB
        }

        Behavior on opacity {
            NumberAnimation { duration: 260; easing.type: Easing.InOutCubic }
        }
    }
}
