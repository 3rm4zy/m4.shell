

import QtQuick
import Quickshell.Io

Item {
    id: root

    required property QtObject config
    property QtObject sidebarState: null

    readonly property var app: (config && config.appearance) ? config.appearance : null
    property color bg:          (app && app.bg          !== undefined) ? app.bg          : "#121212"
    property color bg2:         (app && app.bg2         !== undefined) ? app.bg2         : "#1A1A1A"
    property color red:         (app && app.accent      !== undefined) ? app.accent      : "#B80000"
    property color text:        (app && (app.fg ?? app.text) !== undefined) ? (app.fg ?? app.text) : "#E6E6E6"
    property color muted:       (app && app.muted       !== undefined) ? app.muted       : "#A8A8A8"
    property color borderColor: (app && (app.borderColor ?? app.border) !== undefined) ? (app.borderColor ?? app.border) : "#2A2A2A"

    property int pad: 10
    property int radius: 12
    property int rowH: 30

    implicitHeight: box.implicitHeight
    implicitWidth: 260

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/dgpuctl.sh"

    property string uiMode: ""

    property string machineMode: ""

    property bool ok: true
    property bool hasIcd: false

    readonly property bool dgpuOn: {
        var m = String(root.machineMode || "").toLowerCase()
        if (!m.length) return false

        return (m !== "integrated")
    }

    function keepOpen() { if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar() }
    function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function applyUiFromMachine() { root.uiMode = root.machineMode }

    function refresh() { statusProc.exec(statusProc.command) }

    function runAction(args) {
        runner.command = ["sh", "-lc", root.ctl + " " + args + " >/dev/null 2>&1 || true"]
        runner.exec(runner.command)
    }

    function setIntegratedLogout() {
        if (!root.ok) return
        root.uiMode = "Integrated"
        runAction("set_logout integrated")
    }

    function setHybridLogout() {
        if (!root.ok) return
        root.uiMode = "Hybrid"
        runAction("set_logout hybrid")
    }

    function launchDgpuApp() {
        if (!root.ok) return
        runAction("app")
    }

    function isSelected(modeName) {

        return (String(root.uiMode).toLowerCase() === String(modeName).toLowerCase())
    }

    Process { id: runner }

    Process {
        id: statusProc
        command: ["sh", "-lc", root.ctl + " status"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = (this.text || "")
                if (!raw.length) return

                root.ok = true

                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (!line.length) continue

                    var parts = line.split("|")
                    var tag = parts[0]
                    var val = (parts.slice(1).join("|") || "").trim()

                    if (tag === "NOSUPER") {
                        root.ok = false
                        root.machineMode = ""
                        root.uiMode = ""
                        continue
                    }

                    if (tag === "MODE") {
                        root.machineMode = val
                        continue
                    }

                    if (tag === "ICD") {
                        root.hasIcd = (val && val.length > 0)
                        continue
                    }
                }

                root.applyUiFromMachine()
            }
        }
    }

    Component.onCompleted: root.refresh()

    component PillButton: Rectangle {
        required property string label
        required property bool selected
        required property var onClick

        height: root.rowH
        radius: 10
        color: root.bg
        border.width: 1
        border.color: root.borderColor
        property bool hovered: false
        opacity: root.ok ? 1.0 : 0.6

        Text {
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: 12
            color: parent.hovered ? root.red : (parent.selected ? root.red : root.text)
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.ok ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.ok
            onEntered: { parent.hovered = true; root.keepOpen() }
            onExited:  { parent.hovered = false }
            onClicked: parent.onClick()
        }
    }

    Rectangle {
        id: box
        width: parent ? parent.width : root.implicitWidth
        implicitHeight: col.implicitHeight + (root.pad * 2)

        radius: root.radius
        color: root.bg2
        border.width: 1
        border.color: root.borderColor
        clip: true

        Column {
            id: col
            x: root.pad
            y: root.pad
            width: box.width - (root.pad * 2)
            spacing: 10

            Text {
                text: "dGPU Suite"
                color: root.text
                font.pixelSize: 13
            }

            Column {
                width: parent.width
                spacing: 4

                Text {
                    text: root.ok
                          ? ("Current Mode: " + (root.machineMode.length ? root.machineMode : "Unknown"))
                          : "supergfxctl not found / unavailable"
                    color: root.ok ? root.text : root.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "GPU Mode"
                    color: root.muted
                    font.pixelSize: 11
                }

                Row {
                    width: parent.width
                    spacing: 10
                    readonly property int w: Math.floor((width - spacing) / 2)

                    PillButton {
                        width: parent.w
                        label: "Integrated"
                        selected: root.isSelected("Integrated")
                        onClick: function(){ root.setIntegratedLogout() }
                    }

                    PillButton {
                        width: parent.w
                        label: "Hybrid"
                        selected: root.isSelected("Hybrid")
                        onClick: function(){ root.setHybridLogout() }
                    }
                }
            }

            Column {
                width: parent.width
                visible: root.ok && root.dgpuOn
                spacing: 0

                height: visible ? implicitHeight : 0
                clip: true

                PillButton {
                    width: parent.width
                    label: "Launch dGPU App"
                    selected: false
                    onClick: function(){ root.launchDgpuApp() }
                }
            }
        }
    }
}
