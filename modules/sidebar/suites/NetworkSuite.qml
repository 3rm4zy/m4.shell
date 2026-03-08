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

    property bool nmcliOk: true
    property bool wifiPowered: false
    property string wifiIf: ""
    property string activeType: "none"

    property string activeLabel: ""
    property string activeWifiDevice: ""

    property bool uiWifiPowered: false
    property string uiActiveType: "none"
    property string uiActiveLabel: ""
    property string uiActiveWifiDevice: ""

    property bool scanning: false
    property int scanDurationMs: 15000
    property bool discoveredExpanded: false

    property string selectedSsid: ""
    property string selectedSecurity: ""
    property string password: ""
    property bool forcePromptPassword: false

    property bool connectBusy: false
    property string connectError: ""

    ListModel { id: apModel }

    implicitWidth: 220
    implicitHeight: box.implicitHeight

    Process { id: runner }

    readonly property string ctl: "$HOME/.config/quickshell/m4.shell/scripts/networkctl.sh"

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }
    function releasePanelHover() { }

    function shQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function applyUiFromMachine() {
        uiWifiPowered = wifiPowered
        uiActiveType = activeType
        uiActiveLabel = activeLabel
        uiActiveWifiDevice = activeWifiDevice
    }

    function refresh() { statusProc.exec(statusProc.command) }

    readonly property bool canUseWifi: root.nmcliOk && root.wifiIf.length > 0
    readonly property bool scanEnabled: root.canUseWifi && root.uiWifiPowered
    readonly property bool canDisconnectWifi: root.nmcliOk && root.uiActiveType === "wifi" && root.uiActiveWifiDevice.length > 0

    readonly property bool selectedIsOpen: (root.selectedSecurity === "--" || root.selectedSecurity === "OPEN" || root.selectedSecurity.length === 0)
    readonly property bool selectedIsEnterprise: {
        var s = (root.selectedSecurity || "").toUpperCase()
        return (s.indexOf("802.1X") !== -1 || s.indexOf("EAP") !== -1)
    }
    readonly property bool selectedNeedsPassword: (!root.selectedIsOpen && !root.selectedIsEnterprise)
    readonly property bool shouldPromptPassword: (root.selectedNeedsPassword && root.forcePromptPassword)

    Timer {
        id: refreshTimer
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }
    function _refreshSoon() { refreshTimer.restart() }

    property int scanTicksLeft: 0
    Timer {
        id: scanTick
        interval: 900
        repeat: true
        running: false
        onTriggered: {
            if (!root.scanning) { stop(); return }
            root.refresh()
            root.scanTicksLeft--
            if (root.scanTicksLeft <= 0) stop()
        }
    }

    function setWifiPower(on) {
        if (!root.nmcliOk) return

        root.uiWifiPowered = on
        if (!on) {
            // --- NEW: collapse + "grey out" behavior triggers off scanEnabled/opacity ---
            root.discoveredExpanded = false

            root.scanning = false
            scanStopTimer.stop()
            scanTick.stop()
            root.selectedSsid = ""
            root.selectedSecurity = ""
            root.password = ""
            root.connectError = ""
            root.connectBusy = false
            root.forcePromptPassword = false
            apModel.clear()
            root.uiActiveType = "none"
            root.uiActiveLabel = ""
            root.uiActiveWifiDevice = ""
        }

        runner.command = ["sh", "-lc",
            root.ctl + " wifi_power " + (on ? "on" : "off") + " >/dev/null 2>&1 || true"
        ]
        runner.exec(runner.command)

        _refreshSoon()
    }

    function disconnectActiveWifi() {
        if (!root.canDisconnectWifi || root.connectBusy) return

        root.uiActiveType = "none"
        root.uiActiveLabel = ""
        root.uiActiveWifiDevice = ""

        runner.command = ["sh", "-lc",
            root.ctl + " wifi_disconnect " + shQuote(root.activeWifiDevice) + " >/dev/null 2>&1 || true"
        ]
        runner.exec(runner.command)

        _refreshSoon()
    }

    function startScan() {
        if (!root.scanEnabled) return
        root.scanning = true
        root.discoveredExpanded = true

        runner.command = ["sh", "-lc",
            root.ctl + " wifi_scan " + shQuote(root.wifiIf) + " >/dev/null 2>&1 || true"
        ]
        runner.exec(runner.command)

        scanStopTimer.restart()

        root.scanTicksLeft = Math.ceil(root.scanDurationMs / scanTick.interval)
        scanTick.start()

        _refreshSoon()
    }

    function stopScan() {
        root.scanning = false
        scanStopTimer.stop()
        scanTick.stop()
        _refreshSoon()
    }

    StdioCollector {
        id: connectOut
        waitForEnd: true
        onStreamFinished: {
            var raw = (this.text || "")
            var lines = raw.split("\n")
            var ec = -1
            var msg = ""
            var prompt = false

            for (var i = 0; i < lines.length; i++) {
                var line = (lines[i] || "").trim()
                if (!line.length) continue
                if (line.indexOf("EC|") === 0) ec = Number(line.slice(3))
                else if (line.indexOf("MSG|") === 0) msg = line.slice(4).trim()
                else if (line.indexOf("PROMPT|") === 0) prompt = (line.slice(7).trim() === "1")
            }

            root.connectBusy = false
            if (prompt) root.forcePromptPassword = true

            if (ec === 0) {
                root.password = ""
                root.connectError = ""
                root.selectedSsid = ""
                root.selectedSecurity = ""
                root.forcePromptPassword = false
                root._refreshSoon()
                return
            }

            root.applyUiFromMachine()

            if (ec === -1 && msg.length === 0) {
                var t = raw.trim().replace(/\s+/g, " ").slice(0, 420)
                root.connectError = t.length ? t : "Connect command produced no output."
                root._refreshSoon()
                return
            }

            root.connectError = msg.length ? msg : ("Connect failed (exit code " + String(ec) + ").")
            root._refreshSoon()
        }
    }

    Process { id: connectProc; stdout: connectOut }

    function connectSelected() {
        if (!root.nmcliOk || !root.wifiIf.length) return
        if (!root.selectedSsid.length) return
        if (root.connectBusy) return

        if (root.selectedIsEnterprise) {
            root.connectError = "Enterprise Wi-Fi (802.1X/EAP) requires EAP configuration; not supported by this UI."
            return
        }

        if (root.shouldPromptPassword && !root.password.length) {
            root.connectError = "Password required."
            return
        }

        root.connectBusy = true
        root.connectError = ""

        root.uiActiveType = "wifi"
        root.uiActiveLabel = root.selectedSsid
        root.uiActiveWifiDevice = root.wifiIf

        connectProc.command = ["sh", "-lc",
            root.ctl + " wifi_connect " +
            shQuote(root.wifiIf) + " " +
            shQuote(root.selectedSsid) + " " +
            shQuote(root.selectedSecurity) + " " +
            shQuote(root.password)
        ]
        connectProc.exec(connectProc.command)
    }

    function typeIcon(t) {
        if (t === "wifi") return "󰖩"
        if (t === "ethernet") return "󰈀"
        if (t === "tether") return "󰤮"
        if (t === "other") return "󰌘"
        return "󰖪"
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

            Text { text: "Network Suite"; color: root.text; font.pixelSize: 13 }

            Row {
                id: topRow
                width: parent.width
                height: 30
                spacing: 10

                readonly property int leftW: Math.floor((width - spacing) * 0.5 )
                readonly property int rightW: (width - spacing) - leftW

                Rectangle {
                    id: wifiBtn
                    width: topRow.leftW
                    height: topRow.height
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    property bool hovered: false
                    opacity: root.nmcliOk ? 1.0 : 0.6

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text { height: parent.height; text: "󰖩"; color: wifiBtn.hovered ? root.red : (root.uiWifiPowered ? root.text : root.muted); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: root.uiWifiPowered ? "On" : "Off"; color: wifiBtn.hovered ? root.red : (root.uiWifiPowered ? root.text : root.muted); font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.nmcliOk ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.nmcliOk
                        propagateComposedEvents: true
                        onEntered: { wifiBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { wifiBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.setWifiPower(!root.uiWifiPowered)
                    }
                }

                Rectangle {
                    id: scanBtn
                    width: topRow.rightW
                    height: topRow.height
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    property bool hovered: false
                    opacity: root.scanEnabled ? 1.0 : 0.6

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text { height: parent.height; text: root.scanning ? "󰑐" : "󰍉"; color: scanBtn.hovered ? root.red : (root.scanEnabled ? root.text : root.muted); font.pixelSize: 16; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: root.scanning ? "Scanning" : "Scan"; color: scanBtn.hovered ? root.red : (root.scanEnabled ? root.text : root.muted); font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.scanEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.scanEnabled
                        propagateComposedEvents: true
                        onEntered: { scanBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { scanBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.startScan()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true
                opacity: root.nmcliOk ? 1.0 : 0.6

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        width: 18
                        height: parent.height
                        text: root.typeIcon(root.uiActiveType)
                        color: root.uiActiveLabel.length ? root.text : root.muted
                        font.pixelSize: 16
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        height: parent.height
                        text: root.nmcliOk
                              ? (root.uiActiveLabel.length ? root.uiActiveLabel : "Disconnected")
                              : "nmcli not found"
                        color: root.nmcliOk ? (root.uiActiveLabel.length ? root.text : root.muted) : root.muted
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        width: parent.width - 18 - 10
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.canDisconnectWifi
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    propagateComposedEvents: true
                    onEntered: root.keepPanelHovered()
                    onExited:  root.releasePanelHover()
                    onClicked: root.disconnectActiveWifi()
                }
            }

            Rectangle {
                id: discoveredShell
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true

                // --- NEW: grey out discovered section when Wi-Fi is off ---
                opacity: root.scanEnabled ? 1.0 : 0.6

                readonly property int headerH: 30
                readonly property int bodyH: discoveredCol.implicitHeight + 8

                height: root.discoveredExpanded ? (headerH + bodyH) : headerH
                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Rectangle {
                    width: parent.width
                    height: discoveredShell.headerH
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text { width: 16; height: parent.height; text: root.discoveredExpanded ? "󰅀" : "󰅂"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: "Discovered"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        Item { width: 1; height: 1 }
                        Text { height: parent.height; text: root.scanning ? "󰑐" : ""; color: root.muted; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        // --- NEW: disable collapsing/expanding when Wi-Fi is off ---
                        enabled: root.scanEnabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        propagateComposedEvents: true
                        onEntered: root.keepPanelHovered()
                        onExited:  root.releasePanelHover()
                        onClicked: {
                            root.discoveredExpanded = !root.discoveredExpanded
                            if (root.discoveredExpanded) root.refresh()
                        }
                    }
                }

                Item {
                    x: 0
                    y: discoveredShell.headerH
                    width: discoveredShell.width
                    height: root.discoveredExpanded ? discoveredShell.bodyH : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Column {
                        id: discoveredCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 2

                        Repeater {
                            model: apModel
                            delegate: Rectangle {
                                width: parent.width
                                height: 30
                                radius: 8
                                color: hovered ? root.bg2 : "transparent"
                                property bool hovered: false
                                opacity: root.canUseWifi ? 1.0 : 0.6

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text { width: 16; height: parent.height; text: (model.inUse === "*") ? "󰖩" : "󰤟"; color: (model.inUse === "*") ? root.red : root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                                    Text { height: parent.height; text: model.ssid; color: root.text; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; width: parent.width - 78 }
                                    Text { height: parent.height; text: (model.security && model.security !== "--" && model.security !== "OPEN") ? "󰌾" : ""; color: root.muted; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                                    Text { height: parent.height; text: String(model.signal) + "%"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    // --- NEW: disable list interaction when Wi-Fi is off ---
                                    enabled: root.scanEnabled && !root.connectBusy
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                    propagateComposedEvents: true
                                    onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                    onExited:  { parent.hovered = false; root.releasePanelHover() }
                                    onClicked: {
                                        root.selectedSsid = model.ssid
                                        root.selectedSecurity = model.security
                                        root.connectError = ""
                                        root.password = ""
                                        root.forcePromptPassword = false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: connectBox
                width: parent.width
                radius: 10
                color: root.bg
                border.width: 1
                border.color: root.borderColor
                clip: true

                visible: root.selectedSsid.length > 0
                height: visible ? (connectCol.implicitHeight + 20) : 0
                opacity: root.canUseWifi ? 1.0 : 0.6

                Column {
                    id: connectCol
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 18
                        spacing: 8
                        Text { height: parent.height; text: "Connect:"; color: root.muted; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                        Text { height: parent.height; text: root.selectedSsid; color: root.text; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; width: parent.width - 70 }
                    }

                    Item {
                        width: parent.width
                        height: root.shouldPromptPassword ? 28 : 0
                        visible: root.shouldPromptPassword

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: root.bg2
                            border.width: 1
                            border.color: root.borderColor
                            clip: true

                            TextInput {
                                id: passInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 5
                                anchors.bottomMargin: 5

                                enabled: root.canUseWifi && !root.connectBusy
                                activeFocusOnPress: true
                                echoMode: TextInput.Password
                                passwordCharacter: "*"
                                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                                selectByMouse: true
                                color: root.text
                                font.pixelSize: 12

                                text: root.password
                                onTextChanged: root.password = text

                                Keys.onReturnPressed: root.connectSelected()
                                Keys.onEnterPressed:  root.connectSelected()
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.IBeamCursor
                                propagateComposedEvents: true
                                onEntered: root.keepPanelHovered()
                                onExited:  root.releasePanelHover()
                                onClicked: passInput.forceActiveFocus()
                            }

                            Text {
                                anchors.fill: passInput
                                text: "Password"
                                color: root.muted
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                visible: (passInput.text.length === 0 && !passInput.activeFocus)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.connectError
                        color: root.red
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        visible: root.connectError.length > 0
                    }

                    Row {
                        width: parent.width
                        height: 28
                        spacing: 10

                        Rectangle {
                            id: cancelBtn
                            width: Math.floor((parent.width - 10) * 0.40)
                            height: parent.height
                            radius: 8
                            color: root.bg2
                            border.width: 1
                            border.color: hovered ? root.red : root.borderColor
                            property bool hovered: false
                            opacity: root.connectBusy ? 0.6 : 1.0

                            Text { anchors.centerIn: parent; text: "Cancel"; color: cancelBtn.hovered ? root.red : root.text; font.pixelSize: 12 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.connectBusy
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                propagateComposedEvents: true
                                onEntered: { cancelBtn.hovered = true; root.keepPanelHovered() }
                                onExited:  { cancelBtn.hovered = false; root.releasePanelHover() }
                                onClicked: {
                                    root.selectedSsid = ""
                                    root.selectedSecurity = ""
                                    root.password = ""
                                    root.connectError = ""
                                    root.forcePromptPassword = false
                                }
                            }
                        }

                        Rectangle {
                            id: connectBtn
                            width: parent.width - cancelBtn.width - 10
                            height: parent.height
                            radius: 8
                            color: root.bg2
                            border.width: 1
                            border.color: hovered ? root.red : root.borderColor
                            property bool hovered: false

                            readonly property bool enabledNow: (
                                root.canUseWifi &&
                                root.selectedSsid.length > 0 &&
                                !root.connectBusy &&
                                !root.selectedIsEnterprise &&
                                (!root.shouldPromptPassword || root.password.length > 0)
                            )
                            opacity: enabledNow ? 1.0 : 0.6

                            Text { anchors.centerIn: parent; text: root.connectBusy ? "Connecting" : "Connect"; color: connectBtn.hovered ? root.red : root.text; font.pixelSize: 12 }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: connectBtn.enabledNow
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                propagateComposedEvents: true
                                onEntered: { connectBtn.hovered = true; root.keepPanelHovered() }
                                onExited:  { connectBtn.hovered = false; root.releasePanelHover() }
                                onClicked: root.connectSelected()
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: scanStopTimer
        interval: root.scanDurationMs
        running: false
        repeat: false
        onTriggered: root.stopScan()
    }

    Process {
        id: statusProc
        command: ["sh", "-lc", root.ctl + " status"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var raw = this.text
                if (!raw) return

                var newAps = []
                var gotAnyAp = false

                var lines = raw.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = (lines[i] || "").trim()
                    if (!line.length) continue

                    var parts = line.split("|")
                    var tag = parts[0]

                    if (tag === "NONMCLI") {
                        root.nmcliOk = false
                        root.wifiPowered = false
                        root.wifiIf = ""
                        root.activeType = "none"
                        root.activeWifiDevice = ""
                        root.activeLabel = ""
                        root.scanning = false
                        scanStopTimer.stop()
                        scanTick.stop()
                        root.applyUiFromMachine()
                        continue
                    }

                    if (tag === "WIFIPWR") {
                        root.nmcliOk = true
                        root.wifiPowered = (parts[1] === "1")
                        if (!root.wifiPowered) {
                            root.scanning = false
                            scanStopTimer.stop()
                            scanTick.stop()
                        }
                        continue
                    }

                    if (tag === "WIFIDEV") {
                        root.wifiIf = (parts[1] || "").trim()
                        continue
                    }

                    if (tag === "ACTIVE") {
                        root.activeType = (parts[1] || "none").trim()
                        root.activeWifiDevice = (parts[2] || "").trim()
                        root.activeLabel = (parts.slice(3).join("|") || "").trim()
                        continue
                    }

                    if (tag === "AP") {
                        gotAnyAp = true
                        var inUse = (parts[1] || "")
                        var ssid = (parts[2] || "")
                        var sec = (parts[3] || "--")
                        var sig = Number(parts[4] || 0)
                        if (!ssid.length) continue

                        var idx = -1
                        for (var k = 0; k < newAps.length; k++) {
                            if (newAps[k].ssid === ssid) { idx = k; break }
                        }
                        var newSig = isNaN(sig) ? 0 : sig

                        if (idx >= 0) {
                            var existingSig = newAps[idx].signal
                            var existingInUse = newAps[idx].inUse
                            if (inUse === "*" && existingInUse !== "*") newAps[idx] = { inUse: inUse, ssid: ssid, security: sec, signal: newSig }
                            else if (!(existingInUse === "*" && inUse !== "*") && newSig > existingSig) newAps[idx] = { inUse: inUse, ssid: ssid, security: sec, signal: newSig }
                        } else {
                            newAps.push({ inUse: inUse, ssid: ssid, security: sec, signal: newSig })
                        }
                        continue
                    }
                }

                if (gotAnyAp) {
                    apModel.clear()
                    for (var j = 0; j < newAps.length; j++) apModel.append(newAps[j])
                }

                if (!root.connectBusy) root.applyUiFromMachine()
            }
        }
    }

    Component.onCompleted: {
        root.focus = true
        root.refresh()
    }
}