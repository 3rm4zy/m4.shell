import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string current: settings.wallpaperPath
    property int reloadSerial: 0

    readonly property string swaylockExportScript: Quickshell.shellDir + "/scripts/swaylock.sh"

    property Process swaylockExportProc: Process {
        id: p
    }

    function exportToSwaylock(path) {
        if (!path || path === "")
            return

        if (swaylockExportProc.running)
            swaylockExportProc.running = false

        swaylockExportProc.command = ["bash", swaylockExportScript, path]
        swaylockExportProc.running = true
    }

    function setWallpaper(path) {
        if (!path || path === "")
            return

        settings.wallpaperPath = path
        reloadSerial++

        exportToSwaylock(path)
    }

    Component.onCompleted: {
        if (root.current && root.current !== "")
            exportToSwaylock(root.current)
    }

    property Settings settings: Settings {
        category: "m4.shell"
        property string wallpaperPath: ""
    }
}