

import QtQuick
import Quickshell.Io

Item {
    id: root

    required property QtObject config
    property QtObject sidebarState: null

    readonly property var app: (config && config.appearance) ? config.appearance : null
    property color bg:          (app && app.bg          !== undefined && app.bg          !== null) ? app.bg          : "#121212"
    property color bg2:         (app && app.bg2         !== undefined && app.bg2         !== null) ? app.bg2         : "#1A1A1A"
    property color red:         (app && app.accent      !== undefined && app.accent      !== null) ? app.accent      : "#B80000"
    property color text:        (app && app.fg          !== undefined && app.fg          !== null) ? app.fg          : "#E6E6E6"
    property color muted:       (app && app.muted       !== undefined && app.muted       !== null) ? app.muted       : "#A8A8A8"
    property color borderColor: (app && app.borderColor !== undefined && app.borderColor !== null) ? app.borderColor : "#2A2A2A"

    property int pad: 10
    property int radius: 12
    property int rowH: 30

    implicitWidth: 220
    implicitHeight: box.implicitHeight

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/visualctl.sh"

    function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    property real brightness01: 1

    property bool brightnessAvailable: true

    property bool blueLightOn: false

    property int hyprsunsetTemperature: 3600

    function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }

    function releasePanelHover() { }

    function setBrightnessPct(v01) {
        var vv = _clamp(v01, 0.01, 1.0)
        var pct = Math.round(vv * 100)

        runner.command = ["sh", "-lc", root.ctl + " set brightness " + String(pct) + " >/dev/null 2>&1 || true"]
        runner.exec(runner.command)

        _refreshSoon()
    }

    function refreshBrightness() {
        brightProc.exec(brightProc.command)
    }

    function refreshBlueLightState() {
        hyprsunsetCheckProc.exec(hyprsunsetCheckProc.command)
    }

    function startBlueLight() {
        hyprsunsetStartProc.command = ["sh", "-lc",
            root.ctl + " blue on " + String(root.hyprsunsetTemperature) + " >/dev/null 2>&1 || true"
        ]
        hyprsunsetStartProc.exec(hyprsunsetStartProc.command)
        _refreshSoon()
    }

    function stopBlueLight() {
        runner.command = ["sh", "-lc", root.ctl + " blue off >/dev/null 2>&1 || true"]
        runner.exec(runner.command)
        _refreshSoon()
    }

    function toggleBlueLight() {
        if (root.blueLightOn) stopBlueLight()
        else startBlueLight()
    }

    function refreshAll() {
        refreshBrightness()
        refreshBlueLightState()
    }

    function _refreshSoon() { refreshTimer.restart() }

    Rectangle {
        id: box
        width: parent ? parent.width : root.implicitWidth
        implicitHeight: col.implicitHeight + (root.pad * 2)

        radius: root.radius
        antialiasing: true
        color: root.bg2
        border.width: 1
        border.color: root.borderColor

        Column {
            id: col
            x: root.pad
            y: root.pad
            width: box.width - (root.pad * 2)
            spacing: 10

            Text {
                text: "Visual Suite"
                color: root.text
                font.pixelSize: 13
            }

            ValueSlider {
                width: parent.width
                label: "Brightness"
                value: root.brightness01
                accent: root.red
                text: root.text
                mutedText: root.muted
                track: root.borderColor
                maxVol: 1.0
                enabled: root.brightnessAvailable
                opacity: root.brightnessAvailable ? 1.0 : 0.6
                onValueCommitted: (v) => {
                    if (root.brightnessAvailable) root.setBrightnessPct(v)
                }
            }

            Item {
                width: parent.width
                height: root.rowH

                Row {
                    anchors.fill: parent
                    spacing: 8

                    Text {
                        width: 20
                        height: parent.height
                        text: root.blueLightOn ? "󰖔" : "󰖨"
                        color: root.muted
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        height: parent.height
                        width: parent.width - 28
                        radius: 10
                        color: root.bg
                        border.width: 1
                        border.color: root.borderColor

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                height: parent.height
                                text: "Blue light filter"
                                color: root.text
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                width: parent.width - 50
                            }

                            Rectangle {
                                width: 34
                                height: 18
                                radius: 9
                                color: root.blueLightOn ? root.red : root.borderColor
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: root.text
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: root.blueLightOn ? (parent.width - width - 2) : 2
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true
                            onEntered: root.keepPanelHovered()
                            onExited: root.releasePanelHover()
                            onClicked: root.toggleBlueLight()
                        }
                    }
                }
            }
        }
    }

    component ValueSlider: Item {
        id: s

        property string label: ""
        property real value: 0.0
        property bool muted: false
        property real maxVol: 1.0

        property string accent: "#B80000"
        property string text: "#E6E6E6"
        property string mutedText: "#A8A8A8"
        property string track: "#262626"

        readonly property int rowSpacing: 10
        readonly property int labelW: 88
        readonly property int valueW: 44

        property real displayValue: value
        property bool dragging: false

        signal valueCommitted(real v)

        height: 30
        width: 200

        property real _pending: 0.0

        Timer {
            id: commitTimer
            interval: 25
            running: false
            repeat: false
            onTriggered: s.valueCommitted(s._pending)
        }

        onValueChanged: {
            if (!s.dragging) s.displayValue = s.value
        }

        Row {
            anchors.fill: parent
            spacing: s.rowSpacing

            Text {
                width: s.labelW
                height: parent.height
                text: s.label
                color: s.mutedText
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            Item {
                id: trackBox
                height: parent.height
                width: Math.max(60, s.width - s.labelW - s.valueW - (s.rowSpacing * 2))

                Rectangle {
                    id: base
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: s.track
                }

                Rectangle {
                    anchors.verticalCenter: base.verticalCenter
                    width: Math.max(0, Math.min(base.width, (s.displayValue / s.maxVol) * base.width))
                    height: base.height
                    radius: 2
                    color: s.accent
                }

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: s.text
                    border.width: 1
                    border.color: s.track
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(base.width - width, (s.displayValue / s.maxVol) * base.width - (width / 2)))
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    propagateComposedEvents: true

                    onEntered: root.keepPanelHovered()
                    onExited: root.releasePanelHover()

                    function setFromX(mx) {
                        var t = mx / base.width
                        t = Math.max(0, Math.min(1, t))
                        var v = t * s.maxVol

                        s.dragging = true
                        s.displayValue = v

                        s._pending = v
                        commitTimer.restart()
                    }

                    onPressed: (mouse) => setFromX(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) setFromX(mouse.x) }
                    onReleased: () => { s.dragging = false }
                }
            }

            Text {
                width: s.valueW
                height: parent.height
                text: Math.round((s.displayValue / s.maxVol) * 100) + "%"
                color: s.text
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    Process { id: runner }

    Process {
        id: brightProc
        command: ["sh", "-lc", root.ctl + " status_brightness"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = (this.text || "").trim()
                if (!raw.length) {
                    root.brightnessAvailable = false
                    return
                }

                var avail = null
                var pct = null

                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (!line.length) continue
                    var parts = line.split("|")
                    var tag = parts[0]
                    var val = (parts.slice(1).join("|") || "").trim()

                    if (tag === "BRIGHT_AVAIL") avail = (val === "1")
                    else if (tag === "BRIGHT_PCT") pct = Number(val)
                }

                if (avail === false) {
                    root.brightnessAvailable = false
                    return
                }

                root.brightnessAvailable = true
                if (pct !== null && isFinite(pct)) {
                    root.brightness01 = root._clamp(pct / 100.0, 0.0, 1.0)
                }
            }
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var e = (this.text || "").trim()
                if (e) root.brightnessAvailable = false
            }
        }
    }

    Process {
        id: hyprsunsetCheckProc
        command: ["sh", "-lc", root.ctl + " status_bluelight"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = (this.text || "").trim()
                if (!raw.length) return

                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (!line.length) continue
                    var parts = line.split("|")
                    if (parts[0] === "BLUELIGHT") {
                        root.blueLightOn = ((parts[1] || "").trim() === "1")
                        return
                    }
                }
            }
        }
    }

    Process {
        id: hyprsunsetStartProc
        stdout: StdioCollector { waitForEnd: false }
        stderr: StdioCollector { waitForEnd: false }
    }

    Timer {
        id: refreshTimer
        interval: 300
        running: false
        repeat: false
        onTriggered: root.refreshAll()
    }

    Timer {
        id: pollTimer
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.refreshAll()
    }

    Component.onCompleted: root.refreshAll()
}
