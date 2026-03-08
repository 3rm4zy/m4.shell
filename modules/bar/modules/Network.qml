import QtQuick
import Quickshell.Io

Row {
    id: root

    height: 30
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    spacing: 8

    property string red: "#B80000"
    property string bg2: "#1A1A1A"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string borderColor: "#2A2A2A"

    property string kind: "none"

    property string iface: ""
    property string ssid: ""

    property real upMbps: 0
    property real downMbps: 0
    property real _prevRx: 0
    property real _prevTx: 0
    property real _prevMs: 0
    property string _prevIface: ""

    readonly property int ssidMaxWidth: 170

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/networkctl.sh"

    function _iconForKind(k) {
        if (k === "wifi") return "󰖩"

        if (k === "ethernet") return "󰈀"

        if (k === "tether") return "󰕓"

        return "󰤭"

    }

    function _fmtMbps(v) {
        if (!isFinite(v) || v < 0) return "0.0"
        if (v > 999.9) return "999.9"
        return v.toFixed(1)
    }

    Text {
        height: root.height
        anchors.verticalCenter: root.verticalCenter
        text: root._iconForKind(root.kind)
        color: root.text
        font.pixelSize: 18
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        height: root.height
        anchors.verticalCenter: root.verticalCenter
        text: (root.kind === "wifi") ? (root.ssid && root.ssid.length ? root.ssid : "") : ""
        color: root.text
        font.pixelSize: 12
        elide: Text.ElideRight
        maximumLineCount: 1
        verticalAlignment: Text.AlignVCenter
        visible: text.length > 0
        width: Math.min(root.ssidMaxWidth, implicitWidth)
    }

    Row {
        height: root.height
        anchors.verticalCenter: root.verticalCenter
        spacing: 10

        Row {
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: root.muted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                text: root._fmtMbps(root.upMbps) + " Mbps"
                color: root.text
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }

        Row {
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                color: root.muted
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                text: root._fmtMbps(root.downMbps) + " Mbps"
                color: root.text
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-lc", root.ctl + " bar"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const raw = this.text
                if (!raw) return

                const lines = raw.split("\n")
                const header = (lines[0] || "").trim()
                const ssidLine = (lines.length > 1) ? (lines[1] || "").trim() : ""

                const parts = header.split("\t")
                if (parts.length < 4) return

                const newKind = parts[0] || "none"
                const newIface = parts[1] || ""
                const rx = Number(parts[2])
                const tx = Number(parts[3])

                root.kind = newKind
                root.iface = newIface
                root.ssid = ssidLine

                const nowMs = Date.now()

                if (!root._prevMs || root._prevIface !== newIface) {
                    root._prevIface = newIface
                    root._prevMs = nowMs
                    root._prevRx = isFinite(rx) ? rx : 0
                    root._prevTx = isFinite(tx) ? tx : 0
                    root.upMbps = 0
                    root.downMbps = 0
                    return
                }

                const dt = (nowMs - root._prevMs) / 1000.0
                if (dt <= 0) return

                const drx = (isFinite(rx) ? rx : 0) - root._prevRx
                const dtx = (isFinite(tx) ? tx : 0) - root._prevTx

                root._prevMs = nowMs
                root._prevRx = isFinite(rx) ? rx : 0
                root._prevTx = isFinite(tx) ? tx : 0

                root.downMbps = Math.max(0, (drx * 8.0) / (dt * 1000000.0))
                root.upMbps = Math.max(0, (dtx * 8.0) / (dt * 1000000.0))
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: netProc.exec(netProc.command)
    }

    Component.onCompleted: netProc.exec(netProc.command)
}
