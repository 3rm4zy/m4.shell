import Quickshell
import Quickshell.Wayland
import QtQuick

import qs.components.controls
import "modules"

import "../../services" as S

PanelWindow {
    id: root
    required property QtObject config
    required property QtObject sidebarState
    required property var screenRef

    screen: screenRef
    anchors { top: true; left: true; right: true }
    implicitHeight: config.appearance.barHeight
    focusable: false

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "m4.shell:bar:" + (screenRef && screenRef.name !== undefined ? String(screenRef.name) : "default")

    function pick(a, b, fallback) { return (a !== undefined) ? a : ((b !== undefined) ? b : fallback) }

    readonly property string bg:     pick(config.appearance.bg,     undefined, "#0B0B0B")
    readonly property string bg2:    pick(config.appearance.bg2,    undefined, "#141414")
    readonly property string fg:     pick(config.appearance.fg,     config.appearance.text, "#E6E6E6")
    readonly property string accent: pick(config.appearance.accent, config.appearance.red,  "#B80000")
    readonly property string border: pick(config.appearance.border, config.appearance.borderColor, "#262626")
    readonly property real opac:     pick(config.appearance.opacity, undefined, 0.92)
    readonly property int pad:       pick(config.appearance.pad, undefined, 12)

    Rectangle {
        anchors.fill: parent
        color: root.bg
        opacity: root.opac
    }

    S.Time { id: time }

    function toggleSidebarPinned() {
        if (sidebarState && sidebarState.togglePinned)
            sidebarState.togglePinned()
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30

        IconButton {
            icon: ""

            baseColor: root.fg
            hoverColor: root.accent
            iconSize: 24
            hitSize: 26
            onClicked: root.toggleSidebarPinned()
        }

        ResourceDials {
            red: root.accent
            bg2: root.bg2
            text: root.fg
            borderColor: root.border
            muted: "#A8A8A8"
        }

        Row {
            spacing: 15
            VPN {
                red: root.accent
                bg2: root.bg2
                text: root.fg
                borderColor: root.border
                muted: "#A8A8A8"
            }
            Network {
                red: root.accent
                bg2: root.bg2
                text: root.fg
                borderColor: root.border
                muted: "#A8A8A8"
            }
        }
    }

    Workspaces {
        anchors.centerIn: parent
        screenRef: root.screenRef
        themeRed: root.accent
        themeBg: root.bg2
        themeText: root.fg
        themeMuted: "#A8A8A8"
        themeIdle: "#1A1A1A"
        borderWidth: 1
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: 30

        Tray {
            red: root.accent
            bg: root.bg
            bg2: root.bg2
            text: root.fg
            borderColor: root.border
            muted: "#A8A8A8"
            screenRef: root.screenRef
            barPanel: root
            barPill: null
        }

        Bluetooth {
            red: root.accent
            bg2: root.bg2
            text: root.fg
            borderColor: root.border
            muted: "#A8A8A8"
        }

        Power {
            red: root.accent
            text: root.fg
            muted: "#A8A8A8"
        }

        Volume {
            red: root.accent
            bg2: root.bg2
            text: root.fg
            borderColor: root.border
            muted: "#A8A8A8"
        }

        StyledText {
            appearance: root.config.appearance
            text: time.now
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
