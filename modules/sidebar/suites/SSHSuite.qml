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
    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/sshctl.sh"

    // Panels
    property bool connsExpanded: false
    property bool addExpanded: false

    // Models
    ListModel { id: connModel }

    // Selection
    property string selectedConn: ""

    // State
    property bool holdRefresh: false
    property bool actionRunning: false
    property string lastError: ""

    // Connection form fields
    property bool editingConn: false
    property string formName: ""
    property string formHost: ""
    property string formUser: ""
    property string formPort: "22"
    property string formKeyPath: ""
    property bool formKeyUseNone: false

    Timer {
        id: holdRefreshTimer
        interval: 700
        repeat: false
        onTriggered: root.holdRefresh = false
    }

    Timer {
        id: refreshTimer
        interval: 250
        repeat: false
        onTriggered: if (!root.holdRefresh && !root.actionRunning) root.refreshAll()
    }

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }

    function releasePanelHover() { }

    function userInteracting() {
        root.holdRefresh = true
        holdRefreshTimer.restart()
        root.keepPanelHovered()
    }

    function clearHoldNow() {
        root.holdRefresh = false
        holdRefreshTimer.stop()
    }

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
        root.actionRunning = true
        actionProc.command = ["sh", "-lc", cmd + "; EC=$?; echo __EC:$EC; exit 0"]
        actionProc.exec(actionProc.command)
    }

    function refreshAll() {
        if (root.actionRunning) return
        listProc.exec(listProc.command)
    }

    function _refreshSoon() { refreshTimer.restart() }

    // --- Top button action ---
    function toggleAdd() {
        root.userInteracting()
        root.addExpanded = !root.addExpanded
        if (root.addExpanded) {
            root.editingConn = false
            root.formName = ""
            root.formHost = ""
            root.formUser = ""
            root.formPort = "22"
            root.formKeyPath = ""
            root.formKeyUseNone = false
            root.lastError = ""
        }
    }

    // --- Connection ops ---
    function openEditConn(modelObj) {
        if (!modelObj) return
        root.userInteracting()
        root.addExpanded = true
        root.editingConn = true
        root.formName = modelObj.name || ""
        root.formHost = modelObj.host || ""
        root.formUser = modelObj.user || ""
        root.formPort = String(modelObj.port || "22")
        root.formKeyPath = modelObj.key || ""
        root.formKeyUseNone = (root.formKeyPath.length === 0)
    }

    function saveConn() {
        var nm = safeName(root.formName)
        var host = String(root.formHost || "").trim()
        var user = String(root.formUser || "").trim()
        var port = String(root.formPort || "22").trim()
        var keyp = root.formKeyUseNone ? "" : String(root.formKeyPath || "").trim()

        if (!nm.length) { root.lastError = "Name is required"; return }
        if (!host.length) { root.lastError = "Host is required"; return }

        root.lastError = ""
        root.addExpanded = false
        clearHoldNow()

        runActionShell(
            root.ctl + " upsert "
                + quote(nm) + " "
                + quote(host) + " "
                + quote(user) + " "
                + quote(port) + " "
                + quote(keyp)
        )
    }

    function deleteConn(name) {
        var nm = safeName(name)
        if (!nm.length || root.actionRunning) return
        root.lastError = ""
        clearHoldNow()
        runActionShell(root.ctl + " del " + quote(nm))
    }

    function connectConn(modelObj) {
        if (!modelObj) return
        var host = String(modelObj.host || "").trim()
        if (!host.length) return
        var user = String(modelObj.user || "").trim()
        var port = String(modelObj.port || "").trim()
        var keyp = String(modelObj.key || "").trim()
        var dest = user.length ? (user + "@" + host) : host
        var cmd = "ssh "
        if (port.length) cmd += "-p " + quote(port) + " "
        if (keyp.length) cmd += "-i " + quote(keyp) + " -o IdentitiesOnly=yes "
        cmd += quote(dest)
        shTerm(cmd)
    }

    // Processes
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
                tail = tail.slice(Math.max(0, tail.length - 10)).join("\n")
                root.actionRunning = false
                clearHoldNow()
                if (ec === 0) {
                    root.lastError = ""
                } else {
                    root.lastError = tail.length ? tail : ("sshctl failed (" + ec + ")")
                }
                root.refreshAll()
            }
        }
    }

    Process {
        id: listProc
        command: ["sh", "-lc", root.ctl + " list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (root.holdRefresh || root.actionRunning) return
                connModel.clear()
                var out = (this.text || "").trim()
                if (!out.length) { root.selectedConn = ""; return }
                var lines = out.split("\n").map(function(s){ return s.trim() }).filter(function(s){ return !!s })
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("|")
                    connModel.append({
                        name: (p.length > 0) ? p[0] : "",
                        host: (p.length > 1) ? p[1] : "",
                        user: (p.length > 2) ? p[2] : "",
                        port: (p.length > 3) ? p[3] : "",
                        key:  (p.length > 4) ? p.slice(4).join("|") : ""
                    })
                }
                var hasSel = false
                for (var j = 0; j < connModel.count; j++) {
                    if (connModel.get(j).name === root.selectedConn) { hasSel = true; break }
                }
                if (!hasSel) root.selectedConn = (connModel.count > 0) ? connModel.get(0).name : ""
            }
        }
    }

    // Placeholder overlay for TextInput
    Component {
        id: placeholderTextComp
        Text {
            property Item input: null
            text: ""
            color: root.muted
            font.pixelSize: 12
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            visible: input && (String(input.text || "").length === 0)
        }
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

            // Header
            Row {
                width: parent.width
                height: 18
                spacing: 6
                Text { text: "SSH Suite"; color: root.text; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
                Text {
                    visible: root.actionRunning || (root.lastError.length > 0)
                    text: root.actionRunning ? "Working..." : ("Error: " + root.lastError)
                    elide: Text.ElideRight
                    topPadding: 3
                    color: root.actionRunning ? root.muted : root.red
                    font.pixelSize: 10
                }
            }

            // Connections accordion
            Rectangle {
                id: connShell
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true
                readonly property int headerH: 30
                readonly property int bodyH: connCol.implicitHeight + 8
                height: root.connsExpanded ? (headerH + bodyH) : headerH
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width
                    height: connShell.headerH
                    color: "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10
                        Text { width: 16; height: parent.height; text: root.connsExpanded ? "󰅀" : "󰅂"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Connections"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.userInteracting()
                        onPressed: root.userInteracting()
                        onClicked: {
                            root.connsExpanded = !root.connsExpanded
                            if (root.connsExpanded) root.refreshAll()
                        }
                    }
                }

                Item {
                    x: 0
                    y: connShell.headerH
                    width: connShell.width
                    height: root.connsExpanded ? connShell.bodyH : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Column {
                        id: connCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 2

                        Repeater {
                            model: connModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 30
                                radius: 8
                                color: root.bg

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Rectangle {
                                        width: parent.width - 92
                                        height: 30
                                        radius: 8
                                        color: rowBtn.hovered ? root.bg2 : root.bg
                                        property bool hovered: false
                                        id: rowBtn

                                        Text {
                                            width: 16
                                            height: parent.height
                                            text: "󰒍"
                                            color: root.muted
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
                                            onEntered: { rowBtn.hovered = true; root.keepPanelHovered() }
                                            onExited:  { rowBtn.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.connectConn(model)
                                        }
                                    }

                                    Rectangle {
                                        width: 42
                                        height: 24
                                        y: 3
                                        radius: 10
                                        color: root.bg2
                                        border.width: 1
                                        border.color: editBtn.hovered ? root.red : root.borderColor
                                        property bool hovered: false
                                        id: editBtn
                                        Text { anchors.centerIn: parent; text: "Edit"; color: editBtn.hovered ? root.red : root.text; font.pixelSize: 11 }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !root.actionRunning
                                            onEntered: { editBtn.hovered = true; root.keepPanelHovered() }
                                            onExited:  { editBtn.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.openEditConn(model)
                                        }
                                    }

                                    Rectangle {
                                        width: 42
                                        height: 24
                                        y: 3
                                        radius: 10
                                        color: root.bg2
                                        border.width: 1
                                        border.color: delBtn.hovered ? root.red : root.borderColor
                                        property bool hovered: false
                                        id: delBtn
                                        Text { anchors.centerIn: parent; text: "Del"; color: delBtn.hovered ? root.red : root.text; font.pixelSize: 11 }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !root.actionRunning
                                            onEntered: { delBtn.hovered = true; root.keepPanelHovered() }
                                            onExited:  { delBtn.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.deleteConn(model.name)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: (connModel.count === 0) ? "No connections yet" : ""
                            color: root.muted
                            font.pixelSize: 11
                            visible: (connModel.count === 0)
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // Add button
            Rectangle {
                id: addBtn
                width: parent.width
                height: root.rowH
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                property bool hovered: false

                Row {
                    anchors.centerIn: parent
                    height: parent.height
                    spacing: 8
                    Text { height: parent.height; text: ""; color: addBtn.hovered ? root.red : root.text; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                    Text { height: parent.height; text: "Add Connection"; color: addBtn.hovered ? root.red : root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    propagateComposedEvents: true
                    onEntered: { addBtn.hovered = true; root.keepPanelHovered() }
                    onExited:  { addBtn.hovered = false; root.releasePanelHover() }
                    onPressed: root.userInteracting()
                    onClicked: root.toggleAdd()
                }
            }

            // Inline: Add connection Panels
            Rectangle {
                id: addPanel
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true
                readonly property int bodyH: addCol.implicitHeight + 12
                height: root.addExpanded ? bodyH : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    id: addCol
                    x: 10
                    y: 8
                    width: parent.width - 20
                    spacing: 8

                    Text { 
                        text: root.editingConn ? "Edit connection" : "New connection"
                        color: root.text
                        font.pixelSize: 12 
                    }

                    // Name
                    Text { text: "Name"; color: root.muted; font.pixelSize: 11 }
                    Rectangle {
                        width: parent.width; height: 34; radius: 10
                        color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                        TextInput {
                            id: connName
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            color: root.text; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            text: root.formName
                            onTextChanged: root.formName = text
                            validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9_.-]{0,48}/ }
                        }
                    }

                    // Host
                    Text { text: "Host"; color: root.muted; font.pixelSize: 11 }
                    Rectangle {
                        width: parent.width; height: 34; radius: 10
                        color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                        TextInput {
                            id: connHost
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            color: root.text; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            text: root.formHost
                            onTextChanged: root.formHost = text
                        }
                    }

                    // User & Port
                    Row {
                        width: parent.width
                        spacing: 8

                        Column {
                            width: (parent.width - 8) * 0.62
                            spacing: 4
                            Text { text: "User"; color: root.muted; font.pixelSize: 11 }
                            Rectangle {
                                width: parent.width; height: 34; radius: 10
                                color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                                TextInput {
                                    id: connUser
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    color: root.text; font.pixelSize: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    text: root.formUser
                                    onTextChanged: root.formUser = text
                                }
                            }
                        }

                        Column {
                            width: (parent.width - 8) * 0.38
                            spacing: 4
                            Text { text: "Port"; color: root.muted; font.pixelSize: 11 }
                            Rectangle {
                                width: parent.width; height: 34; radius: 10
                                color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                                TextInput {
                                    id: connPort
                                    anchors.fill: parent
                                    anchors.leftMargin: 10; anchors.rightMargin: 10
                                    color: root.text; font.pixelSize: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    selectByMouse: true
                                    text: root.formPort
                                    onTextChanged: root.formPort = text
                                    validator: RegularExpressionValidator { regularExpression: /[0-9]{0,5}/ }
                                }
                            }
                        }
                    }

                    // Private key section
                    Text { text: "Key"; color: root.muted; font.pixelSize: 11 }
                    Rectangle {
                        width: parent.width; height: 34; radius: 10
                        color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                        opacity: root.formKeyUseNone ? 0.6 : 1.0
                        TextInput {
                            id: connKeyPath
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            enabled: !root.formKeyUseNone
                            color: root.text; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            text: root.formKeyPath
                            onTextChanged: root.formKeyPath = text
                        }
                        Loader {
                            anchors.centerIn: parent
                            visible: !root.formKeyUseNone
                            sourceComponent: placeholderTextComp
                            onLoaded: { item.input = connKeyPath; item.text = "e.g. ~/.ssh/id_ed25519" }
                        }
                    }

                    // Cancel & Create buttons
                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        Rectangle {
                            id: addCancel
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor
                            property bool hovered: false
                            Text { anchors.centerIn: parent; text: "Cancel"; color: addCancel.hovered ? root.red : root.muted; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: addCancel.hovered = true
                                onExited:  addCancel.hovered = false
                                onPressed: root.userInteracting()
                                onClicked: root.addExpanded = false
                            }
                        }

                        Rectangle {
                            id: addSave
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor
                            property bool hovered: false
                            Text { anchors.centerIn: parent; text: root.editingConn ? "Save" : "Create"; color: addSave.hovered ? root.red : root.text; font.pixelSize: 12 }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: addSave.hovered = true
                                onExited:  addSave.hovered = false
                                onPressed: root.userInteracting()
                                onClicked: root.saveConn()
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.focus = true
        root.refreshAll()
    }
}