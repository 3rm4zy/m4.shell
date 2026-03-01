import QtQuick
import Quickshell.Bluetooth

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

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btAvailable: adapter !== null

    property bool powered: btAvailable ? adapter.enabled : false
    property bool scanning: btAvailable ? adapter.discovering : false

    property bool discoveredExpanded: true
    property bool actionRunning: false
    property string lastError: ""

    implicitWidth: 220
    implicitHeight: box.implicitHeight

    function keepPanelHovered() {
        if (sidebarState && sidebarState.enterSidebar) sidebarState.enterSidebar()
    }
    function releasePanelHover() { }

    readonly property var allDevicesSorted: {
        const vals = Bluetooth.devices?.values ?? [];
        return vals.slice().sort((a, b) => {
            const dc = (b.connected ? 1 : 0) - (a.connected ? 1 : 0);
            if (dc !== 0) return dc;
            const dp = (b.paired ? 1 : 0) - (a.paired ? 1 : 0);
            if (dp !== 0) return dp;
            const an = (a.name || a.deviceName || a.address || "").toLowerCase();
            const bn = (b.name || b.deviceName || b.address || "").toLowerCase();
            if (an < bn) return -1;
            if (an > bn) return 1;
            return 0;
        });
    }

    readonly property var pairedDevices: allDevicesSorted.filter(d => d.paired)
    readonly property var discoveredDevices: allDevicesSorted.filter(d => !d.paired)

    function setPower(on) {
        if (!btAvailable) return;
        lastError = "";
        actionRunning = true;
        try {
            adapter.enabled = on;
            if (!on) {
                adapter.discovering = false;
                discoveredExpanded = false;
            }
        } catch (e) {
            lastError = String(e);
        }
        actionRunning = false;
    }

    function setScan(on) {
        if (!btAvailable) return;
        if (!adapter.enabled) return;
        lastError = "";
        actionRunning = true;
        discoveredExpanded = true;
        try {
            adapter.discovering = on;
        } catch (e) {
            lastError = String(e);
        }
        actionRunning = false;
    }

    function toggleScan() { setScan(!scanning) }

    function connectOrDisconnect(deviceObj) {
        if (!btAvailable) return;
        if (!adapter.enabled) return;
        if (!deviceObj) return;

        lastError = "";
        actionRunning = true;
        try {
            deviceObj.connected = !deviceObj.connected;
        } catch (e) {
            lastError = String(e);
        }
        actionRunning = false;
    }

    function pairAndConnect(deviceObj) {
        if (!btAvailable) return;
        if (!adapter.enabled) return;
        if (!deviceObj) return;

        lastError = "";
        actionRunning = true;
        try {
            deviceObj.pair();
            deviceObj.trusted = true;
            deviceObj.connected = true;
        } catch (e) {
            lastError = String(e);
        }
        actionRunning = false;
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

            Text { text: "Bluetooth Suite"; color: root.text; font.pixelSize: 13 }

            Text {
                width: parent.width
                text: root.btAvailable ? root.lastError : "No Bluetooth adapter detected."
                color: root.red
                font.pixelSize: 10
                wrapMode: Text.Wrap
                visible: (!root.btAvailable) || (root.lastError.length > 0)
            }

            Row {
                width: parent.width
                height: 30
                spacing: 10

                readonly property int powerW: Math.floor((width - spacing) * 0.5)
                readonly property int scanW:  (width - spacing) - powerW

                Rectangle {
                    id: powerBtn
                    height: parent.height
                    width: parent.powerW
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    property bool hovered: false
                    opacity: (root.btAvailable && !root.actionRunning) ? 1.0 : 0.6

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text {
                            height: parent.height
                            text: root.powered ? "󰂯" : "󰂲"
                            color: powerBtn.hovered ? root.red : (root.powered ? root.text : root.muted)
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            height: parent.height
                            text: root.powered ? "On" : "Off"
                            color: powerBtn.hovered ? root.red : (root.powered ? root.text : root.muted)
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.btAvailable && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.btAvailable && !root.actionRunning
                        propagateComposedEvents: true
                        onEntered: { powerBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { powerBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.setPower(!root.powered)
                    }
                }

                Rectangle {
                    id: scanBtn
                    height: parent.height
                    width: parent.scanW
                    radius: 10
                    color: root.bg
                    border.width: 1
                    border.color: root.borderColor
                    opacity: (root.powered && root.btAvailable && !root.actionRunning) ? 1.0 : 0.6
                    property bool hovered: false

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 8
                        Text {
                            height: parent.height
                            text: root.scanning ? "󰑐" : "󰍉"
                            color: scanBtn.hovered ? root.red : (root.powered ? root.text : root.muted)
                            font.pixelSize: 16
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            height: parent.height
                            text: root.scanning ? "Scan On" : "Scan Off"
                            color: scanBtn.hovered ? root.red : (root.powered ? root.text : root.muted)
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.powered && root.btAvailable && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.powered && root.btAvailable && !root.actionRunning
                        propagateComposedEvents: true
                        onEntered: { scanBtn.hovered = true; root.keepPanelHovered() }
                        onExited:  { scanBtn.hovered = false; root.releasePanelHover() }
                        onClicked: root.toggleScan()
                    }
                }
            }

            Item {
                width: parent.width
                height: (root.pairedDevices.length > 0) ? (pairedHeader.implicitHeight + pairedBox.height + 10) : 0
                visible: root.pairedDevices.length > 0

                Column {
                    anchors.fill: parent
                    spacing: 6

                    Text { id: pairedHeader; text: "Paired"; color: root.muted; font.pixelSize: 11 }

                    Rectangle {
                        id: pairedBox
                        width: parent.width
                        height: Math.min(160, pairedCol.implicitHeight + 8)
                        radius: 10
                        color: root.bg
                        border.width: 1
                        border.color: root.borderColor
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 4
                            contentWidth: width
                            contentHeight: pairedCol.implicitHeight
                            clip: true

                            Column {
                                id: pairedCol
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.pairedDevices
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: parent.width
                                        height: 30
                                        radius: 8
                                        color: hovered ? root.bg2 : "transparent"
                                        property bool hovered: false

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 10

                                            Text {
                                                width: 16
                                                height: parent.height
                                                text: modelData.connected ? "󰂱" : "󰂳"
                                                color: modelData.connected ? root.red : root.muted
                                                font.pixelSize: 16
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Text {
                                                height: parent.height
                                                text: (modelData.name && modelData.name.length) ? modelData.name
                                                      : (modelData.deviceName && modelData.deviceName.length) ? modelData.deviceName
                                                      : modelData.address
                                                color: root.text
                                                font.pixelSize: 12
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                width: parent.width - 90
                                            }

                                            Text {
                                                height: parent.height
                                                text: modelData.connected ? "Disconnect" : "Connect"
                                                color: (root.powered && root.btAvailable && !root.actionRunning)
                                                       ? (modelData.connected ? root.muted : root.text)
                                                       : root.muted
                                                font.pixelSize: 11
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: (root.powered && root.btAvailable && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            enabled: root.powered && root.btAvailable && !root.actionRunning
                                            propagateComposedEvents: true
                                            onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                            onExited:  { parent.hovered = false; root.releasePanelHover() }
                                            onClicked: root.connectOrDisconnect(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                opacity: root.powered && root.btAvailable ? 1.0 : 0.6

                readonly property int headerH: 30
                readonly property int listH: foundCol.implicitHeight + 8

                height: root.discoveredExpanded ? (headerH + listH) : headerH
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
                        cursorShape: (root.powered && root.btAvailable) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.powered && root.btAvailable
                        propagateComposedEvents: true
                        onEntered: root.keepPanelHovered()
                        onExited:  root.releasePanelHover()
                        onClicked: root.discoveredExpanded = !root.discoveredExpanded
                    }
                }

                Item {
                    x: 0
                    y: discoveredShell.headerH
                    width: discoveredShell.width
                    height: root.discoveredExpanded ? discoveredShell.listH : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Column {
                        id: foundCol
                        x: 4
                        y: 4
                        width: parent.width - 8
                        spacing: 2

                        Repeater {
                            model: root.discoveredDevices
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 30
                                radius: 8
                                color: hovered ? root.bg2 : "transparent"
                                property bool hovered: false

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text { width: 16; height: parent.height; text: "󰂲"; color: root.muted; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }

                                    Text {
                                        height: parent.height
                                        text: (modelData.name && modelData.name.length) ? modelData.name
                                              : (modelData.deviceName && modelData.deviceName.length) ? modelData.deviceName
                                              : modelData.address
                                        color: root.text
                                        font.pixelSize: 12
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        width: parent.width - 30
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: (root.powered && root.btAvailable && !root.actionRunning) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    enabled: root.powered && root.btAvailable && !root.actionRunning
                                    propagateComposedEvents: true
                                    onEntered: { parent.hovered = true; root.keepPanelHovered() }
                                    onExited:  { parent.hovered = false; root.releasePanelHover() }
                                    onClicked: root.pairAndConnect(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.focus = true
    }
}