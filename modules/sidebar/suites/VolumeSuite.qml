import QtQuick
import Quickshell.Io

import "../../components"

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

    readonly property string audioctlPath: "$HOME/.config/quickshell/m4.shell/scripts/audioctl.sh"

    ListModel { id: sinkModel }
    ListModel { id: sourceModel }

    property int defaultSinkId: -1
    property int defaultSourceId: -1
    property real sinkVol01: 0.0
    property bool sinkMuted: false
    property real sourceVol01: 0.0
    property bool sourceMuted: false

    property int uiDefaultSinkId: -1
    property int uiDefaultSourceId: -1
    property real uiSinkVol01: 0.0
    property bool uiSinkMuted: false
    property real uiSourceVol01: 0.0
    property bool uiSourceMuted: false

    readonly property real maxVol: 1.5

    property bool sinksOpen: false
    property bool sourcesOpen: false

    property bool actionRunning: false
    property string lastError: ""

    implicitWidth: 220
    implicitHeight: box.implicitHeight

    function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }
    function releasePanelHover() { }

    function currentNameForId(model, idv) {
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).id === idv) return model.get(i).name
        }
        return ""
    }

    function applyUiFromMachine() {
        uiDefaultSinkId = defaultSinkId
        uiDefaultSourceId = defaultSourceId
        uiSinkVol01 = sinkVol01
        uiSinkMuted = sinkMuted
        uiSourceVol01 = sourceVol01
        uiSourceMuted = sourceMuted
    }

    function refreshAll() {
        if (actionRunning) return
        statusProc.exec(statusProc.command)
    }

    Timer {
        id: refreshTimer
        interval: 250
        repeat: false
        onTriggered: root.refreshAll()
    }
    function _refreshSoon() { refreshTimer.restart() }

    Process { id: volumeRunner }

    Process {
        id: actionProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var out = (this.text || "")
                var m = out.match(/__EC:(\d+)/)
                var ec = m ? parseInt(m[1]) : 999

                root.actionRunning = false

                if (ec === 0) {
                    root.lastError = ""
                    root._refreshSoon()
                } else {
                    root.lastError = out.trim().split("\n").slice(-6).join("\n")
                    root.applyUiFromMachine()
                    root._refreshSoon()
                }
            }
        }
    }

    function runShellLocked(shellCmd) {
        root.actionRunning = true
        actionProc.command = ["sh", "-lc", shellCmd + "; EC=$?; echo __EC:$EC; exit 0"]
        actionProc.exec(actionProc.command)
    }

    function runShellVolume(shellCmd) {
        volumeRunner.command = ["sh", "-lc", shellCmd + " >/dev/null 2>&1 || true"]
        volumeRunner.exec(volumeRunner.command)
        root._refreshSoon()
    }

    function setDefaultSink(idv) {
        if (!isFinite(idv) || idv <= 0 || root.actionRunning) return
        lastError = ""

        uiDefaultSinkId = idv
        sinksOpen = false

        runShellLocked(root.audioctlPath + " set-default sink " + String(idv) + " >/dev/null 2>&1")
    }

    function setDefaultSource(idv) {
        if (!isFinite(idv) || idv <= 0 || root.actionRunning) return
        lastError = ""

        uiDefaultSourceId = idv
        sourcesOpen = false

        runShellLocked(root.audioctlPath + " set-default source " + String(idv) + " >/dev/null 2>&1")
    }

    function toggleSinkMute() {
        if (root.actionRunning) return
        lastError = ""
        uiSinkMuted = !uiSinkMuted
        runShellLocked("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1")
    }

    function toggleSourceMute() {
        if (root.actionRunning) return
        lastError = ""
        uiSourceMuted = !uiSourceMuted
        runShellLocked("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle >/dev/null 2>&1")
    }

    function setSinkVol(v) {
        lastError = ""
        var vv = _clamp(v, 0.0, maxVol)
        uiSinkVol01 = vv
        runShellVolume("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + vv.toFixed(2))
    }

    function setSourceVol(v) {
        lastError = ""
        var vv = _clamp(v, 0.0, maxVol)
        uiSourceVol01 = vv
        runShellVolume("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + vv.toFixed(2))
    }

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

            Row {
                width: parent.width
                height: 18
                spacing: 8

                Text { text: "Audio Suite"; color: root.text; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }

                Text {
                    text: root.lastError.length ? "⚠ " + root.lastError : ""
                    color: root.red
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    width: parent.width - 52
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
                        text: root.uiSinkMuted ? "󰖁" : "󰕾"
                        color: root.uiSinkMuted ? root.muted : root.text
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true
                            enabled: !root.actionRunning
                            onEntered: root.keepPanelHovered()
                            onExited:  root.releasePanelHover()
                            onClicked: root.toggleSinkMute()
                        }
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
                                text: root.currentNameForId(sinkModel, root.uiDefaultSinkId) || "Output device"
                                color: root.text
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                width: parent.width - 20
                            }

                            Text {
                                height: parent.height
                                text: root.sinksOpen ? "󰅀" : "󰅂"
                                color: root.muted
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true
                            enabled: !root.actionRunning
                            onEntered: root.keepPanelHovered()
                            onExited:  root.releasePanelHover()
                            onClicked: {
                                root.sinksOpen = !root.sinksOpen
                                if (root.sinksOpen) {
                                    root.sourcesOpen = false
                                    root.refreshAll()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: root.sinksOpen ? Math.min(160, listOut.implicitHeight + 8) : 0
                radius: 10
                color: root.bg
                border.width: root.sinksOpen ? 1 : 0
                border.color: root.borderColor
                clip: true
                visible: root.sinksOpen

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 4
                    contentWidth: width
                    contentHeight: listOut.implicitHeight
                    clip: true
                    interactive: listOut.implicitHeight > height

                    Column {
                        id: listOut
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: sinkModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 28
                                radius: 8
                                color: hovered ? root.bg2 : "transparent"
                                property bool hovered: false

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    text: model.name
                                    color: (model.id === root.uiDefaultSinkId) ? root.red : root.text
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    propagateComposedEvents: true
                                    enabled: !root.actionRunning
                                    onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                    onExited:  { parent.hovered = false; root.releasePanelHover() }
                                    onClicked: root.setDefaultSink(model.id)
                                }
                            }
                        }
                    }
                }
            }

            ValueSlider {
                width: parent.width
                label: "Output"
                value: root.uiSinkVol01
                muted: root.uiSinkMuted
                accent: root.red
                text: root.text
                mutedText: root.muted
                track: root.borderColor
                maxVol: root.maxVol
                enabled: !root.actionRunning
                opacity: enabled ? 1.0 : 0.6
                onValueCommitted: (v) => root.setSinkVol(v)
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
                        text: root.uiSourceMuted ? "󰍭" : "󰍬"
                        color: root.uiSourceMuted ? root.muted : root.text
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true
                            enabled: !root.actionRunning
                            onEntered: root.keepPanelHovered()
                            onExited:  root.releasePanelHover()
                            onClicked: root.toggleSourceMute()
                        }
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
                                text: root.currentNameForId(sourceModel, root.uiDefaultSourceId) || "Input device"
                                color: root.text
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                width: parent.width - 20
                            }

                            Text {
                                height: parent.height
                                text: root.sourcesOpen ? "󰅀" : "󰅂"
                                color: root.muted
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            propagateComposedEvents: true
                            enabled: !root.actionRunning
                            onEntered: root.keepPanelHovered()
                            onExited:  root.releasePanelHover()
                            onClicked: {
                                root.sourcesOpen = !root.sourcesOpen
                                if (root.sourcesOpen) {
                                    root.sinksOpen = false
                                    root.refreshAll()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: root.sourcesOpen ? Math.min(160, listIn.implicitHeight + 8) : 0
                radius: 10
                color: root.bg
                border.width: root.sourcesOpen ? 1 : 0
                border.color: root.borderColor
                clip: true
                visible: root.sourcesOpen

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 4
                    contentWidth: width
                    contentHeight: listIn.implicitHeight
                    clip: true
                    interactive: listIn.implicitHeight > height

                    Column {
                        id: listIn
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: sourceModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 28
                                radius: 8
                                color: hovered ? root.bg2 : "transparent"
                                property bool hovered: false

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    text: model.name
                                    color: (model.id === root.uiDefaultSourceId) ? root.red : root.text
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    propagateComposedEvents: true
                                    enabled: !root.actionRunning
                                    onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                    onExited:  { parent.hovered = false; root.releasePanelHover() }
                                    onClicked: root.setDefaultSource(model.id)
                                }
                            }
                        }
                    }
                }
            }

            ValueSlider {
                width: parent.width
                label: "Input"
                value: root.uiSourceVol01
                muted: root.uiSourceMuted
                accent: root.red
                text: root.text
                mutedText: root.muted
                track: root.borderColor
                maxVol: root.maxVol
                enabled: (root.uiDefaultSourceId > 0) && !root.actionRunning
                opacity: enabled ? 1.0 : 0.6
                onValueCommitted: (v) => {
                    if (root.uiDefaultSourceId > 0) root.setSourceVol(v)
                }
            }
        }
    }

    Process {
        id: statusProc
        command: ["sh", "-lc", root.audioctlPath + " list"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var t = (this.text || "").trim()

                sinkModel.clear()
                sourceModel.clear()
                root.defaultSinkId = -1
                root.defaultSourceId = -1

                if (!t.length) {

                    root.lastError = "No audio nodes returned by audioctl"
                    root.applyUiFromMachine()
                    return
                }

                root.lastError = ""

                var lines = t.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (!line.length) continue

                    var parts = line.split("\t")
                    if (parts.length < 4) continue

                    var kind = parts[0]
                    var isDef = (parseInt(parts[1], 10) === 1)
                    var idv = parseInt(parts[2], 10)
                    var name = parts.slice(3).join("\t").trim()

                    if (!isFinite(idv) || idv <= 0 || !name.length) continue

                    if (kind === "SINK") {
                        sinkModel.append({ id: idv, name: name, isDefault: isDef })
                        if (isDef) root.defaultSinkId = idv
                    } else if (kind === "SOURCE") {
                        sourceModel.append({ id: idv, name: name, isDefault: isDef })
                        if (isDef) root.defaultSourceId = idv
                    }
                }

                sinkVolProc.exec(sinkVolProc.command)
                sourceVolProc.exec(sourceVolProc.command)
            }
        }
    }

    Process {
        id: sinkVolProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var text = (this.text || "").trim()
                if (!text) return
                var volMatch = text.match(/Volume:\s*([\d.]+)/)
                if (volMatch) {
                    var vol = parseFloat(volMatch[1])
                    if (isFinite(vol) && vol >= 0) root.sinkVol01 = vol
                }
                root.sinkMuted = /\[MUTED\]/i.test(text)
                root.applyUiFromMachine()
            }
        }
    }

    Process {
        id: sourceVolProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var text = (this.text || "").trim()
                if (!text) return
                var volMatch = text.match(/Volume:\s*([\d.]+)/)
                if (volMatch) {
                    var vol = parseFloat(volMatch[1])
                    if (isFinite(vol) && vol >= 0) root.sourceVol01 = vol
                }
                root.sourceMuted = /\[MUTED\]/i.test(text)
                root.applyUiFromMachine()
            }
        }
    }

    Component.onCompleted: root.refreshAll()
}
