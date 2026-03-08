import QtQuick
import Quickshell.Io

Item {
    id: root

    height: 30
    implicitWidth: 22
    width: implicitWidth

    property string red: "#B80000"
    property string bg2: "#1A1A1A"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string borderColor: "#2A2A2A"

    property bool connected: false

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/vpnctl.sh"

    function iconForState() {

        return root.connected ? "󰦝" : "󰦞"
    }

    Text {
        anchors.centerIn: parent
        text: root.iconForState()
        color: root.connected ? root.text : root.muted
        font.pixelSize: 18
        verticalAlignment: Text.AlignVCenter
    }

    Process {
        id: vpnProc
        command: ["sh", "-lc", root.ctl + " bar_status"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var t = (this.text || "").trim()

                root.connected = (t === "1")
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: vpnProc.exec(vpnProc.command)
    }

    Component.onCompleted: vpnProc.exec(vpnProc.command)
}
