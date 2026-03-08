

import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

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

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
    readonly property int pct: hasBattery ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool onBattery: UPower.onBattery

    function formatSeconds(s, fallback) {
        const day = Math.floor(s / 86400);
        const hr = Math.floor(s / 3600) % 60;
        const min = Math.floor(s / 60) % 60;

        let comps = [];
        if (day > 0) comps.push(day + " days");
        if (hr > 0) comps.push(hr + " hours");
        if (min > 0) comps.push(min + " mins");
        return comps.join(", ") || fallback;
    }

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/powerctl.sh"

    property string uiProfile: ""

    property string machineProfile: ""

    property bool profileOk: true

    function keepOpen() { if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar() }
    function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function applyUiFromMachine() { root.uiProfile = root.machineProfile }

    function refresh() { statusProc.exec(statusProc.command) }

    function setProfile(p) {
        if (!root.profileOk) return

        root.uiProfile = p

        runner.command = ["sh", "-lc", root.ctl + " set " + shQuote(p) + " >/dev/null 2>&1 || true"]
        runner.exec(runner.command)

        refreshTimer.restart()
    }

    function isSelected(p) { return root.uiProfile === p }

    Timer {
        id: refreshTimer
        interval: 250
        repeat: false
        onTriggered: root.refresh()
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

                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (!line.length) continue

                    var parts = line.split("|")
                    var tag = parts[0]
                    var val = (parts.slice(1).join("|") || "").trim()

                    if (tag === "NOPPD") {
                        root.profileOk = false
                        root.machineProfile = ""
                        root.uiProfile = ""
                        continue
                    }

                    if (tag === "PROFILE") {
                        root.profileOk = true
                        root.machineProfile = val
                        continue
                    }
                }

                root.applyUiFromMachine()
            }
        }
    }

    Component.onCompleted: {
        root.refresh()
    }

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
        opacity: root.profileOk ? 1.0 : 0.6

        Text {
            anchors.centerIn: parent
            text: parent.label
            font.pixelSize: 12
            color: parent.hovered ? root.red : (parent.selected ? root.red : root.text)
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.profileOk ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.profileOk
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
                text: "Power Suite"
                color: root.text
                font.pixelSize: 13
            }

            Row {
                spacing: 10
                Text {
                    text: root.hasBattery ? ("Juice: " + root.pct + "%") : "No battery detected"
                    color: root.text
                    font.pixelSize: 12
                }

                Text {
                    visible: root.hasBattery
                    text: (root.onBattery ? "" : "Charging: ") + (root.onBattery
                            ? root.formatSeconds(UPower.displayDevice.timeToEmpty, "Calculating…")
                            : root.formatSeconds(UPower.displayDevice.timeToFull, "Fully charged!"))
                    color: root.muted
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    topPadding: 2
                }
            }

            Rectangle {
                visible: (typeof PowerProfiles !== "undefined") &&
                         PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                width: parent.width
                radius: 10
                color: root.red
                opacity: 0.15
                border.width: 1
                border.color: root.red

                implicitHeight: warnCol.implicitHeight + 12

                Column {
                    id: warnCol
                    spacing: 4
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "Performance Degraded"
                        color: root.red
                        font.pixelSize: 12
                    }
                    Text {
                        text: "Reason: " + PerformanceDegradationReason.toString(PowerProfiles.degradationReason)
                        color: root.muted
                        font.pixelSize: 11
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: "CPU Power Mode"
                    color: root.muted
                    font.pixelSize: 11
                }

                Row {
                    width: parent.width
                    spacing: 10
                    readonly property int w: Math.floor((width - (spacing * 2)) / 3)

                    PillButton { width: parent.w; label: "Low";  selected: root.isSelected("power-saver");  onClick: function(){ root.setProfile("power-saver") } }
                    PillButton { width: parent.w; label: "Med";  selected: root.isSelected("balanced");     onClick: function(){ root.setProfile("balanced") } }
                    PillButton { width: parent.w; label: "High"; selected: root.isSelected("performance");  onClick: function(){ root.setProfile("performance") } }
                }

                Text {
                    visible: !root.profileOk
                    text: "power-profiles-daemon not available"
                    color: root.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}
