import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: root
    required property QtObject config
    required property QtObject sidebarState

    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "m4.shell:sidebar"

    readonly property int ew: (config && config.sidebar && config.sidebar.edgeWidth !== undefined)
        ? config.sidebar.edgeWidth
        : 8

    readonly property int r: (config && config.sidebar && config.sidebar.edgeCornerRadius !== undefined)
        ? config.sidebar.edgeCornerRadius
        : 20

    readonly property string edgeSide: (config && config.sidebar && config.sidebar.edgeForScreen)
        ? config.sidebar.edgeForScreen(screen ? screen.name : "")
        : "left"

    readonly property int barH: (config && config.appearance && config.appearance.barHeight !== undefined)
        ? config.appearance.barHeight
        : 40

    readonly property real slide: sidebarState ? sidebarState.slide : 0

    anchors {
        top: true
        bottom: true
        left:  edgeSide === "left"
        right: edgeSide === "right"
    }

    margins { top: barH - 1 }

    implicitWidth: ew + slide + r

    HoverHandler {
        id: rootHH
        grabPermissions: PointerHandler.TakeOverForbidden

        onHoveredChanged: root.syncOpenState()
        onPointChanged:  root.syncOpenState()
    }

    Timer {
        id: closeDebounce
        interval: 120
        repeat: false
        onTriggered: root._closeIfStillOutside()
    }

    property bool pendingLeave: false

    function inActiveRegion(): bool {
        if (!root.sidebarState) return false
        if (!rootHH.hovered) return false
        const x = rootHH.point.position.x
        const s = Math.max(0, root.sidebarState.slide || 0)
        const total = root.ew + s
        if (root.edgeSide === "left")
            return x >= 0 && x <= total
        return x >= 0 && x <= root.width
    }

    function syncOpenState() {
        if (!root.sidebarState) return

        if (inActiveRegion()) {
            pendingLeave = false
            closeDebounce.stop()
            root.sidebarState.enterSidebar()
            return
        }

        if (!closeDebounce.running)
            closeDebounce.start()
    }

    function _closeIfStillOutside() {
        if (!root.sidebarState) return

        if (inActiveRegion()) {
            pendingLeave = false
            return
        }

        if (root.sidebarState.slideAnim?.running) {
            pendingLeave = true
            return
        }

        pendingLeave = false
        root.sidebarState.leaveSidebar()
    }

    Connections {
        target: root.sidebarState ? root.sidebarState.slideAnim : null
        function onRunningChanged() {
            if (!root.sidebarState) return
            if (!root.sidebarState.slideAnim.running && root.pendingLeave) {
                root.pendingLeave = false
                if (!root.inActiveRegion())
                    root.sidebarState.leaveSidebar()
            }
        }
    }

    Rectangle {
        id: edgeStrip
        z: 3
        x: (root.edgeSide === "left") ? 0 : (root.slide + root.r)
        width: root.ew
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: root.config.appearance.bg
        opacity: root.config.appearance.opacity
        HoverHandler {
            grabPermissions: PointerHandler.TakeOverForbidden
            onHoveredChanged: {
                if (hovered && root.sidebarState)
                    root.sidebarState.enterSidebar()
            }
        }
    }

    Item {
        id: body
        z: 2
        x: (root.edgeSide === "left") ? root.ew : root.r
        width: Math.max(0, root.slide)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.fill: parent
            color: root.config.appearance.bg
            opacity: root.config.appearance.opacity
        }
        SidebarMenu {
            anchors.fill: parent
            config: root.config
            sidebarState: root.sidebarState
            screen: root.screen
        }
    }

    Item {
        z: 4
        width: r
        height: r
        x: (edgeSide === "left") ? (ew + slide) : 0
        y: 0
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.fill: parent
            color: root.config.appearance.bg
            opacity: root.config.appearance.opacity
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: topMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
        Item {
            id: topMask
            width: r
            height: r
            clip: true
            visible: false
            layer.enabled: true
            Rectangle {
                width: 2 * r
                height: 2 * r
                radius: r
                color: "white"
                x: (edgeSide === "left") ? 0 : -r
                y: 0
            }
        }
    }

    Item {
        z: 4
        width: r
        height: r
        anchors.bottom: parent.bottom
        x: (edgeSide === "left") ? (ew + slide) : 0
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.fill: parent
            color: root.config.appearance.bg
            opacity: root.config.appearance.opacity
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskInverted: true
                maskSource: bottomMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
        Item {
            id: bottomMask
            width: r
            height: r
            clip: true
            visible: false
            layer.enabled: true
            Rectangle {
                width: 2 * r
                height: 2 * r
                radius: r
                color: "white"
                x: (edgeSide === "left") ? 0 : -r
                y: -r
            }
        }
    }
}
