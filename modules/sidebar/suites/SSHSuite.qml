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
    readonly property string ctl: "$HOME/.config/quickshell/MazyShell/scripts/sshctl.sh"

    // Panels
    property bool connsExpanded: false
    property bool addExpanded: false      // inline connection form
    property bool keysExpanded: false     // keys list accordion
    property bool keyMgrExpanded: false   // inline key manager form

    // Models
    ListModel { id: connModel }
    ListModel { id: keyModel }

    // Selection
    property string selectedConn: ""
    property string selectedKeyLabel: ""
    property string selectedKeyPath: ""

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

    // Key manager fields
    property bool generatingKey: false
    property bool editingKey: false
    property string keyLabel: ""
    property string keyPath: ""
    property string keyComment: ""
    property string genKeyName: ""
    property string genKeyPassphrase: ""

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
        keysProc.exec(keysProc.command)
    }
    function _refreshSoon() { refreshTimer.restart() }

    // --- Top button actions ---
    function toggleAdd() {
        root.userInteracting()
        root.addExpanded = !root.addExpanded
        if (root.addExpanded) {
            root.keyMgrExpanded = false
            root.editingConn = false
            root.formName = ""
            root.formHost = ""
            root.formUser = ""
            root.formPort = "22"
            root.formKeyPath = root.selectedKeyPath || ""
            root.formKeyUseNone = (root.formKeyPath.length === 0)
            root.lastError = ""
        }
    }

    function toggleKeyMgr() {
        root.userInteracting()
        root.keyMgrExpanded = !root.keyMgrExpanded
        if (root.keyMgrExpanded) {
            root.addExpanded = false
            root.editingKey = false
            root.generatingKey = false
            root.keyLabel = ""
            root.keyPath = ""
            root.keyComment = ""
            root.genKeyName = ""
            root.genKeyPassphrase = ""
            root.lastError = ""
        }
    }

    // --- Connection ops ---
    function openEditConn(modelObj) {
        if (!modelObj) return
        root.userInteracting()
        root.addExpanded = true
        root.keyMgrExpanded = false

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

    // --- Key ops ---
    function selectKey(modelObj) {
        if (!modelObj) return
        root.selectedKeyLabel = modelObj.label
        root.selectedKeyPath = modelObj.path
    }

    function openEditKey(modelObj) {
        if (!modelObj) return
        root.userInteracting()
        root.keyMgrExpanded = true
        root.addExpanded = false

        root.editingKey = true
        root.generatingKey = false
        root.keyLabel = modelObj.label || ""
        root.keyPath = modelObj.path || ""
        root.keyComment = ""
        root.genKeyName = ""
        root.genKeyPassphrase = ""
        root.lastError = ""
    }

    function addOrUpdateExistingKey() {
        var label = safeName(root.keyLabel)
        var path = String(root.keyPath || "").trim()
        if (!label.length) { root.lastError = "Key label is required"; return }
        if (!path.length) { root.lastError = "Key path is required"; return }

        root.lastError = ""
        root.keyMgrExpanded = false

        // key_add overwrites existing label in keys.db (update behavior)
        clearHoldNow()

        runActionShell(root.ctl + " key_add " + quote(label) + " " + quote(path))
    }

    function genNewKey() {
        var label = safeName(root.keyLabel)
        var fname = String(root.genKeyName || "").trim()
        var comment = String(root.keyComment || "").trim()
        var pass = String(root.genKeyPassphrase || "")

        if (!label.length) { root.lastError = "Key label is required"; return }
        if (!fname.length) { root.lastError = "Filename is required"; return }

        root.lastError = ""
        root.keyMgrExpanded = false

        clearHoldNow()

        runActionShell(
            root.ctl + " key_gen "
                + quote(label) + " "
                + quote(fname) + " "
                + quote(comment) + " "
                + quote(pass)
        )
    }

    function deleteKey(label) {
        var lb = safeName(label)
        if (!lb.length || root.actionRunning) return
        root.lastError = ""

        clearHoldNow()

        runActionShell(root.ctl + " key_del " + quote(lb))
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
        id: keysProc
        command: ["sh", "-lc", root.ctl + " key_list"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (root.holdRefresh || root.actionRunning) return

                keyModel.clear()
                var out = (this.text || "").trim()
                if (out.length) {
                    var lines = out.split("\n").map(function(s){ return s.trim() }).filter(function(s){ return !!s })
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split("|")
                        var label = (parts.length > 0) ? parts[0] : ""
                        var path  = (parts.length > 1) ? parts.slice(1).join("|") : ""
                        keyModel.append({ label: label, path: path })
                    }
                }

                // keep selection stable
                var found = false
                for (var j = 0; j < keyModel.count; j++) {
                    if (keyModel.get(j).label === root.selectedKeyLabel) {
                        root.selectedKeyPath = keyModel.get(j).path
                        found = true
                        break
                    }
                }
                if (!found) {
                    if (keyModel.count > 0) {
                        root.selectedKeyLabel = keyModel.get(0).label
                        root.selectedKeyPath = keyModel.get(0).path
                    } else {
                        root.selectedKeyLabel = ""
                        root.selectedKeyPath = ""
                    }
                }

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

            // Add / Keys row (hover fixed)
            Row {
                width: parent.width
                height: root.rowH
                spacing: 10

                readonly property int leftW: Math.floor((width - spacing) * 0.5)
                readonly property int rightW: (width - spacing) - leftW

                Rectangle {
                    id: addBtn
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
                        Text { height: parent.height; text: ""; color: addBtn.hovered ? root.red : root.text; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Add"; color: addBtn.hovered ? root.red : root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
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

                Rectangle {
                    id: keysBtn
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
                        Text { height: parent.height; text: "󰌆"; color: keysBtn.hovered ? root.red : root.text; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Keys"; color: keysBtn.hovered ? root.red : root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        propagateComposedEvents: true
                        onEntered: { keysBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { keysBtn.hovered = false; root.releasePanelHover() }
                        onPressed: root.userInteracting()
                        onClicked: root.toggleKeyMgr()
                    }
                }
            }

            // Inline: Add connection panel (pushes content down)
            Rectangle {
                id: addPanel
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true

                readonly property int headerH: 0
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

                    Text { text: root.editingConn ? "Edit connection" : "New connection"; color: root.text; font.pixelSize: 12 }

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

                    Row {
                        width: parent.width
                        height: 34
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

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 15
                        Text { text: root.selectedKeyLabel.length ? ("Key Selected: " + root.selectedKeyLabel) : "Key Selected: none"; color: root.muted; font.pixelSize: 10 }
                    }

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
                            anchors.fill: parent
                            visible: !root.formKeyUseNone
                            sourceComponent: placeholderTextComp
                            onLoaded: { item.input = connKeyPath; item.text = "e.g. ~/.ssh/id_ed25519" }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 8

                        Rectangle {
                            width: 84; height: 24; radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor
                            property bool hovered: false

                            Text { anchors.centerIn: parent; text: root.formKeyUseNone ? "Key: none" : "Use key"; color: parent.hovered ? root.red : root.text; font.pixelSize: 11 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                onExited:  { parent.hovered = false; root.releasePanelHover() }
                                onPressed: root.userInteracting()
                                onClicked: {
                                    root.formKeyUseNone = !root.formKeyUseNone
                                    if (!root.formKeyUseNone && !root.formKeyPath.length && root.selectedKeyPath.length)
                                        root.formKeyPath = root.selectedKeyPath
                                }
                            }
                        }

                        Rectangle {
                            width: 120; height: 24; radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor
                            property bool hovered: false
                            opacity: (!root.formKeyUseNone && root.selectedKeyPath.length > 0) ? 1.0 : 0.6

                            Text { anchors.centerIn: parent; text: "Use selected"; color: parent.hovered ? root.red : root.text; font.pixelSize: 11 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: (!root.formKeyUseNone && root.selectedKeyPath.length > 0)
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                onExited:  { parent.hovered = false; root.releasePanelHover() }
                                onPressed: root.userInteracting()
                                onClicked: { if (root.selectedKeyPath.length) root.formKeyPath = root.selectedKeyPath }
                            }
                        }
                    }

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
                            border.color: addCancel.hovered ? root.red : root.borderColor
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
                            border.color: addSave.hovered ? root.red : root.borderColor
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

            // Connections accordion (restored)
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

            // Inline key manager panel (pushes content down)
            Rectangle {
                id: keyMgrPanel
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true

                readonly property int bodyH: keyMgrCol.implicitHeight + 12

                height: root.keyMgrExpanded ? bodyH : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    id: keyMgrCol
                    x: 10
                    y: 8
                    width: parent.width - 20
                    spacing: 8

                    Text { text: "Key manager"; color: root.text; font.pixelSize: 12 }

                    Row {
                        width: parent.width
                        height: 24
                        spacing: 8

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 24
                            radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor

                            Text { anchors.centerIn: parent; text: "Add existing"; color: (!root.generatingKey) ? root.red : root.text; font.pixelSize: 11 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: root.userInteracting()
                                onClicked: { root.generatingKey = false; root.editingKey = false; root.lastError = "" }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 24
                            radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor

                            Text { anchors.centerIn: parent; text: "Generate new"; color: (root.generatingKey) ? root.red : root.text; font.pixelSize: 11 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: root.userInteracting()
                                onClicked: { root.generatingKey = true; root.editingKey = false; root.lastError = "" }
                            }
                        }
                    }

                    Text { text: "Key label"; color: root.muted; font.pixelSize: 11 }
                    Rectangle {
                        width: parent.width; height: 34; radius: 10
                        color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                        TextInput {
                            id: keyLabelInput
                            anchors.fill: parent
                            anchors.leftMargin: 10; anchors.rightMargin: 10
                            color: root.text; font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            text: root.keyLabel
                            onTextChanged: root.keyLabel = text
                            validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9_.-]{0,48}/ }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 6
                        visible: !root.generatingKey

                        Text { text: "Private key path"; color: root.muted; font.pixelSize: 11 }
                        Rectangle {
                            width: parent.width; height: 34; radius: 10
                            color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                            TextInput {
                                id: keyPathInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                color: root.text; font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                text: root.keyPath
                                onTextChanged: root.keyPath = text
                            }
                            Loader {
                                anchors.fill: parent
                                sourceComponent: placeholderTextComp
                                onLoaded: { item.input = keyPathInput; item.text = "e.g. ~/.ssh/id_ed25519" }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 6
                        visible: root.generatingKey

                        Text { text: "Filename (stored in ~/.config/mazyshell/ssh/keys/)"; color: root.muted; font.pixelSize: 11 }
                        Rectangle {
                            width: parent.width; height: 34; radius: 10
                            color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                            TextInput {
                                id: genNameInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                color: root.text; font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                text: root.genKeyName
                                onTextChanged: root.genKeyName = text
                                validator: RegularExpressionValidator { regularExpression: /[A-Za-z0-9_.-]{0,64}/ }
                            }
                            Loader {
                                anchors.fill: parent
                                sourceComponent: placeholderTextComp
                                onLoaded: { item.input = genNameInput; item.text = "e.g. homelab_ed25519" }
                            }
                        }

                        Text { text: "Comment (optional)"; color: root.muted; font.pixelSize: 11 }
                        Rectangle {
                            width: parent.width; height: 34; radius: 10
                            color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                            TextInput {
                                id: keyCommentInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                color: root.text; font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                text: root.keyComment
                                onTextChanged: root.keyComment = text
                            }
                            Loader {
                                anchors.fill: parent
                                sourceComponent: placeholderTextComp
                                onLoaded: { item.input = keyCommentInput; item.text = "e.g. ethan@mazyshell" }
                            }
                        }

                        Text { text: "Passphrase (optional; blank = none)"; color: root.muted; font.pixelSize: 11 }
                        Rectangle {
                            width: parent.width; height: 34; radius: 10
                            color: root.bg2; border.width: 1; border.color: root.borderColor; clip: true
                            TextInput {
                                id: passInput
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                color: root.text
                                echoMode: TextInput.Password
                                font.pixelSize: 12
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                text: root.genKeyPassphrase
                                onTextChanged: root.genKeyPassphrase = text
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor

                            Text { anchors.centerIn: parent; text: "Cancel"; color: root.muted; font.pixelSize: 12 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: root.userInteracting()
                                onClicked: root.keyMgrExpanded = false
                            }
                        }

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 10
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor

                            Text {
                                anchors.centerIn: parent
                                text: root.generatingKey ? "Generate" : (root.editingKey ? "Save" : "Add")
                                color: root.text
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: root.userInteracting()
                                onClicked: {
                                    if (root.generatingKey) root.genNewKey()
                                    else root.addOrUpdateExistingKey()
                                }
                            }
                        }
                    }
                }
            }

            // Keys accordion (list + select + edit + delete)
            Rectangle {
                id: keyShell
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true

                readonly property int headerH: 30
                readonly property int bodyH: keyCol.implicitHeight + 8

                height: root.keysExpanded ? (headerH + bodyH) : headerH
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width
                    height: keyShell.headerH
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text { width: 16; height: parent.height; text: root.keysExpanded ? "󰅀" : "󰅂"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Keys"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        Text {
                            height: parent.height
                            text: root.selectedKeyLabel.length ? ("Selected: " + root.selectedKeyLabel) : "Selected: none"
                            color: root.muted
                            font.pixelSize: 10
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.userInteracting()
                        onPressed: root.userInteracting()
                        onClicked: {
                            root.keysExpanded = !root.keysExpanded
                            if (root.keysExpanded) root.refreshAll()
                        }
                    }
                }

                Item {
                    x: 0
                    y: keyShell.headerH
                    width: keyShell.width
                    height: root.keysExpanded ? keyShell.bodyH : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Column {
                        id: keyCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 2

                        Repeater {
                            model: keyModel
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
                                        color: keyRow.hovered ? root.bg2 : root.bg
                                        property bool hovered: false
                                        id: keyRow

                                        Text {
                                            width: 16
                                            height: parent.height
                                            text: (root.selectedKeyLabel === model.label) ? "" : "󰌋"
                                            color: (root.selectedKeyLabel === model.label) ? root.red : root.muted
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 5
                                        }

                                        Text {
                                            height: parent.height
                                            text: model.label
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
                                            onEntered: { keyRow.hovered = true; root.keepPanelHovered() }
                                            onExited:  { keyRow.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.selectKey(model)
                                        }
                                    }

                                    Rectangle {
                                        width: 42
                                        height: 24
                                        y: 3
                                        radius: 10
                                        color: root.bg2
                                        border.width: 1
                                        border.color: kEdit.hovered ? root.red : root.borderColor
                                        property bool hovered: false
                                        id: kEdit

                                        Text { anchors.centerIn: parent; text: "Edit"; color: kEdit.hovered ? root.red : root.text; font.pixelSize: 11 }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !root.actionRunning
                                            onEntered: { kEdit.hovered = true; root.keepPanelHovered() }
                                            onExited:  { kEdit.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.openEditKey(model)
                                        }
                                    }

                                    Rectangle {
                                        width: 42
                                        height: 24
                                        y: 3
                                        radius: 10
                                        color: root.bg2
                                        border.width: 1
                                        border.color: kDel.hovered ? root.red : root.borderColor
                                        property bool hovered: false
                                        id: kDel

                                        Text { anchors.centerIn: parent; text: "Del"; color: kDel.hovered ? root.red : root.text; font.pixelSize: 11 }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !root.actionRunning
                                            onEntered: { kDel.hovered = true; root.keepPanelHovered() }
                                            onExited:  { kDel.hovered = false; root.releasePanelHover() }
                                            onPressed: root.userInteracting()
                                            onClicked: root.deleteKey(model.label)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: (keyModel.count === 0) ? "No keys registered" : ""
                            color: root.muted
                            font.pixelSize: 11
                            visible: (keyModel.count === 0)
                            wrapMode: Text.Wrap
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