

import QtQuick
import Quickshell.Io

FocusScope {
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

    readonly property var termCmd: ["kitty", "-e"]

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/vpnctl.sh"

    property bool configsExpanded: false

    ListModel { id: cfgModel }

    property var activeIfaces: []

    property string activeName: ""

    property string selectedName: ""

    property bool addOpen: false
    property string newName: ""

    property string lastError: ""
    readonly property string logPath: "/tmp/m4.shell-wg.log"

    property bool holdRefresh: false

    property bool actionRunning: false
    property string optimisticName: ""

    property string prevActiveBeforeAction: ""

    property string ipResult: ""
    property bool ipBusy: false

    Timer {
        id: ipHideTimer
        interval: 5000
        repeat: false
        onTriggered: root.ipResult = ""
    }

    onIpResultChanged: {
        if (root.ipResult && root.ipResult.length > 0) ipHideTimer.restart()
        else ipHideTimer.stop()
    }

    Timer {
        id: holdRefreshTimer
        interval: 700
        repeat: false
        onTriggered: root.holdRefresh = false
    }

    function userInteracting() {
        root.holdRefresh = true
        holdRefreshTimer.restart()
        root.keepPanelHovered()
    }

    Process { id: runner }

    Process {
        id: actionProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var out = (this.text || "")
                var m = out.match(/__EC:(\d+)/)
                var ec = m ? parseInt(m[1]) : 999

                var tail = out.trim().split("\n")
                tail = tail.slice(Math.max(0, tail.length - 8)).join("\n")

                root.actionRunning = false

                if (ec === 0) {
                    root.optimisticName = ""
                    root._refreshSoon()
                } else {
                    root.lastError = tail.length ? tail : ("wg-quick failed (" + ec + ")")
                    root.rollbackOptimistic()
                }
            }
        }
    }

    Process {
        id: ipProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.ipBusy = false
                var v = (this.text || "").trim()
                root.ipResult = v.length ? v : "No response"
            }
        }
    }

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }
    function releasePanelHover() { }

    function quote(s) {
        if (s === null || s === undefined) return "''"
        var str = String(s)
        return "'" + str.replace(/'/g, "'\"'\"'") + "'"
    }

    function safeName(name) {
        return String(name || "").trim().replace(/\s+/g, "_")
    }

    function shTerm(cmd) {
        runner.command = root.termCmd.concat(["sh", "-lc", cmd])
        runner.exec(runner.command)
    }

    function runActionShell(cmd) {
        actionProc.command = ["sh", "-lc", cmd + "; EC=$?; echo __EC:$EC; exit 0"]
        actionProc.exec(actionProc.command)
    }

    function setAllInactive() {
        for (var i = 0; i < cfgModel.count; i++) {
            if (cfgModel.get(i).active) cfgModel.setProperty(i, "active", false)
        }
    }

    function setModelActiveOnly(name) {
        var nm = safeName(name)
        for (var i = 0; i < cfgModel.count; i++) {
            var it2 = cfgModel.get(i)
            cfgModel.setProperty(i, "active", (it2.name === nm))
        }
    }

    function applyOptimisticActive(name) {
        var nm = safeName(name)
        root.prevActiveBeforeAction = root.activeName
        root.optimisticName = nm

        root.activeName = nm
        root.activeIfaces = nm.length ? [nm] : []
        root.selectedName = nm
        setModelActiveOnly(nm)
    }

    function applyOptimisticDisconnected() {
        root.prevActiveBeforeAction = root.activeName
        root.optimisticName = "__DISCONNECTED__"

        root.activeName = ""
        root.activeIfaces = []
        setAllInactive()
    }

    function rollbackOptimistic() {
        var prev = safeName(root.prevActiveBeforeAction)
        root.optimisticName = ""

        if (prev.length) {
            root.activeName = prev
            root.activeIfaces = [prev]
            root.selectedName = prev
            setModelActiveOnly(prev)
        } else {
            root.activeName = ""
            root.activeIfaces = []
            setAllInactive()
        }

        root._refreshSoon()
    }

    function refreshAll() {
        if (root.actionRunning) return
        activeProc.exec(activeProc.command)
    }
    function _refreshSoon() { refreshTimer.restart() }

    function ipTest() {
        if (root.ipBusy) return
        root.lastError = ""
        root.ipResult = ""
        ipHideTimer.stop()

        root.ipBusy = true
        root.userInteracting()

        ipProc.command = ["sh", "-lc", root.ctl + " ip"]
        ipProc.exec(ipProc.command)
    }

    Process {
        id: activeProc
        command: ["sh", "-lc", root.ctl + " active"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var t = (this.text || "").trim()
                root.activeIfaces = t ? t.split(/\s+/).filter(function(x){ return !!x }) : []
                root.activeName = (root.activeIfaces.length > 0) ? root.activeIfaces[0] : ""
                listProc.exec(listProc.command)
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-lc", root.ctl + " list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (root.holdRefresh || root.addOpen || root.actionRunning) return

                cfgModel.clear()

                var out = (this.text || "").trim()
                if (!out) {
                    if (!root.activeName.length) root.selectedName = ""
                    return
                }

                var lines = out.split("\n").map(function(s){ return s.trim() }).filter(function(s){ return !!s })
                for (var i = 0; i < lines.length; i++) {
                    var path = lines[i]
                    var base = path.split("/").pop()
                    var name = base.endsWith(".conf") ? base.slice(0, -5) : base
                    var active = root.activeIfaces.indexOf(name) !== -1
                    cfgModel.append({ name: name, path: path, active: active })
                }

                if (root.activeName.length) {
                    root.selectedName = root.activeName
                } else {
                    var hasSelected = false
                    for (var j = 0; j < cfgModel.count; j++) {
                        if (cfgModel.get(j).name === root.selectedName) { hasSelected = true; break }
                    }
                    if (!hasSelected) root.selectedName = (cfgModel.count > 0) ? cfgModel.get(0).name : ""
                }
            }
        }
    }

    function disconnect(name) {
        if (!name || root.actionRunning) return
        root.lastError = ""

        var nm = safeName(name)

        root.actionRunning = true
        applyOptimisticDisconnected()

        runActionShell(
            root.ctl + " down " + quote(nm) + " " + quote(root.logPath)
        )
    }

    function disconnectActive() {
        if (!root.activeName.length) return
        disconnect(root.activeName)
    }

    function connect(name) {
        if (!name || root.actionRunning) return
        root.lastError = ""

        var nm = safeName(name)

        if (safeName(root.activeName) === nm) {
            disconnect(nm)
            return
        }

        root.actionRunning = true
        applyOptimisticActive(nm)

        runActionShell(
            root.ctl + " up " + quote(nm) + " " + quote(root.prevActiveBeforeAction) + " " + quote(root.logPath)
        )
    }

    function openOrCreateConfig(name) {
        if (!name) return

        var base = safeName(name)

        var cmd = root.ctl + " edit " + quote(base)
        shTerm(cmd)

        _refreshSoon()
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
        clip: true

        Column {
            id: col
            x: root.pad
            y: root.pad
            width: box.width - (root.pad * 2)
            spacing: 10

            Row {
                width: parent.width
                height: 18
                spacing: 6

                Text { text: "VPN Suite"; color: root.text; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }

                Text {
                    visible: root.ipBusy || root.ipResult.length > 0
                    text: root.ipBusy ? "IP: Testing..." : ("IP: " + root.ipResult)
                    elide: Text.ElideRight
                    topPadding:3
                    color: root.muted
                    font.pixelSize: 10
                }
            }

            Row {
                width: parent.width
                height: root.rowH
                spacing: 10

                readonly property int leftW: Math.floor((width - spacing) * 0.5 )
                readonly property int rightW: (width - spacing) - leftW

                Rectangle {
                    id: ipBtn
                    width: parent.leftW
                    height: parent.height
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    property bool hovered: false

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text { height: parent.height; text: "󰈀"; color: ipBtn.hovered ? root.red : root.text; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "IP Test"; color: ipBtn.hovered ? root.red : root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        propagateComposedEvents: true
                        onEntered: { ipBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { ipBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.ipTest()
                        onPressed: root.userInteracting()
                    }
                }

                Rectangle {
                    id: addBtn
                    width: parent.rightW
                    height: parent.height
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    property bool hovered: false

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text { height: parent.height; text: ""; color: addBtn.hovered ? root.red : root.text; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Add Config"; color: addBtn.hovered ? root.red : root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        propagateComposedEvents: true
                        onEntered: { addBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { addBtn.hovered = false; root.releasePanelHover() }
                        onClicked: { root.newName = ""; root.addOpen = true }
                        onPressed: root.userInteracting()
                    }
                }
            }

            Rectangle {
                id: discBtn
                width: parent.width
                height: 34
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                property bool hovered: false
                opacity: root.activeName.length ? 1.0 : 0.6

                Row {
                    leftPadding: 10
                    height: parent.height
                    spacing: 8
                    Text {
                        height: parent.height
                        text: discBtn.hovered ? "" : (root.activeName.length ? "" : "")
                        color: discBtn.hovered ? root.red : (root.activeName.length ? root.text : root.muted)
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        leftPadding: 8
                        height: parent.height
                        text: root.activeName.length ? root.activeName : "Not Connected"
                        color: discBtn.hovered ? root.red : root.text
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.activeName.length > 0 && !root.actionRunning
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    propagateComposedEvents: true
                    onEntered: { discBtn.hovered = true; root.keepPanelHovered() }
                    onExited:  { discBtn.hovered = false; root.releasePanelHover() }
                    onClicked: root.disconnectActive()
                    onPressed: root.userInteracting()
                }
            }

            Rectangle {
                id: cfgShell
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true

                readonly property int headerH: 30
                readonly property int bodyH: cfgCol.implicitHeight + 8

                height: root.configsExpanded ? (headerH + bodyH) : headerH
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                HoverHandler {
                    grabPermissions: PointerHandler.TakeOverForbidden
                    onHoveredChanged: {
                        if (hovered) {
                            root.holdRefresh = true
                            holdRefreshTimer.stop()
                            root.keepPanelHovered()
                        } else {
                            holdRefreshTimer.restart()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: cfgShell.headerH
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text { width: 16; height: parent.height; text: root.configsExpanded ? "󰅀" : "󰅂"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Connections"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        Item { width: 1; height: 1 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        propagateComposedEvents: true
                        onEntered: root.userInteracting()
                        onExited:  root.releasePanelHover()
                        onClicked: {
                            root.configsExpanded = !root.configsExpanded
                            if (root.configsExpanded) root.refreshAll()
                        }
                        onPressed: root.userInteracting()
                    }
                }

                Item {
                    x: 0
                    y: cfgShell.headerH
                    width: cfgShell.width
                    height: root.configsExpanded ? cfgShell.bodyH : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Column {
                        id: cfgCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 2

                        Repeater {
                            model: cfgModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 30
                                radius: 8
                                color: root.bg
                                property bool hovered: false

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: parent.width - 45
                                        height: 30
                                        radius: 8
                                        color: hovered ? root.bg2 : root.bg
                                        property bool hovered: false

                                        Text {
                                            width: 16
                                            height: parent.height
                                            text: model.active ? "" : ""
                                            color: model.active ? root.red : root.muted
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 5
                                        }

                                        Text {
                                            height: parent.height
                                            text: model.name
                                            color: root.text
                                            font.pixelSize: 12
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            leftPadding: 25
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !root.actionRunning
                                            propagateComposedEvents: true
                                            onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                            onExited:  { parent.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: {
                                                root.selectedName = model.name
                                                root.connect(model.name)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 40
                                        height: 24
                                        y: 3
                                        radius: 10
                                        color: root.bg
                                        border.color: root.borderColor
                                        property bool hovered: false

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Edit"
                                            color: parent.hovered ? root.red : root.text
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !root.actionRunning
                                            propagateComposedEvents: true
                                            onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                            onExited:  { parent.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.openOrCreateConfig(model.name)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: (cfgModel.count === 0) ? "No configs in ~/.config/wg" : ""
                            color: root.muted
                            font.pixelSize: 11
                            visible: (cfgModel.count === 0)
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }

        Item {
            id: modal
            anchors.fill: parent
            visible: root.addOpen
            z: 1000

            Rectangle { anchors.fill: parent; color: "#99000000" }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                onPressed: function(mouse){ mouse.accepted = false }
                onClicked: function(mouse){
                    var p = dialog.mapFromItem(modal, mouse.x, mouse.y)
                    if (p.x < 0 || p.y < 0 || p.x > dialog.width || p.y > dialog.height)
                        root.addOpen = false
                }
            }

            Rectangle {
                id: dialog
                width: parent.width - 20
                x: 10
                y: 10
                radius: 12
                color: root.bg2
                border.width: 1
                border.color: root.borderColor

                Column {
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 8

                    Text { text: "New config name"; color: root.text; font.pixelSize: 12 }

                    Rectangle {
                        width: parent.width
                        height: 34
                        radius: 10
                        color: root.bg
                        border.width: 1
                        border.color: root.borderColor
                        clip: true

                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            color: root.text
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter

                            focus: true
                            activeFocusOnPress: true
                            selectByMouse: true

                            text: root.newName
                            onTextChanged: root.newName = text

                            validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9_-]{0,32}/ }

                            Keys.onReturnPressed: createBtn.tryCreate()
                            Keys.onEnterPressed:  createBtn.tryCreate()
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.IBeamCursor
                            propagateComposedEvents: true
                            onClicked: function() {
                                nameInput.forceActiveFocus()
                                root.keepPanelHovered()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        Rectangle {
                            id: cancelBtn
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 10
                            color: root.bg
                            border.width: 1
                            border.color: cancelBtn.hovered ? root.red : root.borderColor
                            property bool hovered: false

                            Text { anchors.centerIn: parent; text: "Cancel"; color: cancelBtn.hovered ? root.red : root.muted; font.pixelSize: 12 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                propagateComposedEvents: true
                                onEntered: cancelBtn.hovered = true
                                onExited:  cancelBtn.hovered = false
                                onClicked: root.addOpen = false
                                onPressed: root.userInteracting()
                            }
                        }

                        Rectangle {
                            id: createBtn
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 10
                            color: root.bg
                            border.width: 1
                            border.color: createBtn.hovered ? root.red : root.borderColor
                            property bool hovered: false
                            opacity: root.newName.length > 0 ? 1.0 : 0.6

                            Text {
                                anchors.centerIn: parent
                                text: "Create & Edit"
                                color: createBtn.hovered ? root.red : (root.newName.length > 0 ? root.text : root.muted)
                                font.pixelSize: 12
                            }

                            function tryCreate() {
                                var nm = root.newName.trim()
                                if (!nm.length) return
                                root.addOpen = false
                                root.openOrCreateConfig(nm)
                                root.configsExpanded = true
                                root.refreshAll()
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.newName.length > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                propagateComposedEvents: true
                                onEntered: createBtn.hovered = true
                                onExited:  createBtn.hovered = false
                                onClicked: createBtn.tryCreate()
                                onPressed: root.userInteracting()
                            }
                        }
                    }
                }
            }

            onVisibleChanged: {
                if (visible) Qt.callLater(function() { nameInput.forceActiveFocus() })
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 250
        repeat: false
        running: false
        onTriggered: if (!root.holdRefresh && !root.addOpen) root.refreshAll()
    }

    Component.onCompleted: {
        root.focus = true
        root.refreshAll()
    }
}
