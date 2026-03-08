import QtQuick
import Quickshell.Io
import Quickshell

QtObject {
    id: root

    property string cfgPath: "$HOME/.config/quickshell/m4.shell/config.json"
    property string ctlPath: "$HOME/.config/quickshell/m4.shell/scripts/configctl.sh"

    property var data: ({})
    property bool loaded: false

    property bool hydrating: false

    property Timer saveTimer: Timer {
        interval: 150
        repeat: false
        onTriggered: root.flush()
    }

    function scheduleSave() {
        if (!loaded || hydrating) return
        saveTimer.restart()
    }

    function quoteForShell(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    property Process loadProc: Process {
        command: ["sh", "-lc", root.ctlPath + " dump"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const txt = (this.text || "").trim()
                if (!txt) return
                try {
                    const obj = JSON.parse(txt)
                    root.applyLoaded(obj)
                } catch (e) {
                    console.error("ConfigService: JSON parse failed:", e)
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const err = (this.text || "").trim()
                if (err) console.error("ConfigService: load stderr:", err)
            }
        }
    }

    function reload() {
        loaded = false
        hydrating = true
        loadProc.exec(loadProc.command)
    }

    property Process saveProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const err = (this.text || "").trim()
                if (err) console.error("ConfigService: save stderr:", err)
            }
        }
    }

    function flush() {
        if (!loaded || hydrating) return
        const payload = JSON.stringify(root.data)

        saveProc.command = ["sh", "-lc", root.ctlPath + " write " + quoteForShell(payload)]
        saveProc.exec(saveProc.command)
    }

    property Process resetProc: Process {
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const err = (this.text || "").trim()
                if (err) console.error("ConfigService: reset stderr:", err)
            }
        }
        onExited: (code) => {
            if (code === 0) root.reload()
        }
    }

    function restoreDefaults() {
        resetProc.command = ["sh", "-lc", root.ctlPath + " reset"]
        resetProc.exec(resetProc.command)
    }

    function get(pathArr, fallback) {
        var cur = root.data
        for (var i = 0; i < pathArr.length; i++) {
            if (!cur || cur[pathArr[i]] === undefined) return fallback
            cur = cur[pathArr[i]]
        }
        return cur
    }

    function setPath(pathArr, value) {
        if (!root.data || typeof root.data !== "object") root.data = ({})
        var cur = root.data
        for (var i = 0; i < pathArr.length - 1; i++) {
            const k = pathArr[i]
            if (cur[k] === undefined || cur[k] === null || typeof cur[k] !== "object")
                cur[k] = {}
            cur = cur[k]
        }
        cur[pathArr[pathArr.length - 1]] = value
        root.data = root.data
        scheduleSave()
    }

    function applyLoaded(obj) {
        hydrating = true
        root.data = (obj && typeof obj === "object") ? obj : ({})

        bg          = String(get(["appearance","bg"], "#0B0B0B"))
        bg2         = String(get(["appearance","bg2"], "#1A1A1A"))
        fg          = String(get(["appearance","fg"], "#E6E6E6"))
        text        = String(get(["appearance","text"], "#E6E6E6"))
        muted       = String(get(["appearance","muted"], "#A8A8A8"))
        accent      = String(get(["appearance","accent"], "#B80000"))
        borderColor = String(get(["appearance","borderColor"], "#2A2A2A"))
        opacity     = Number(get(["appearance","opacity"], 1.0))

        barHeight = parseInt(get(["appearance","barHeight"], 35), 10)
        pad       = parseInt(get(["appearance","pad"], 20), 10)
        fontSize  = parseInt(get(["appearance","fontSize"], 12), 10)
        radius    = parseInt(get(["appearance","radius"], 12), 10)
        animMs    = parseInt(get(["appearance","animMs"], 40), 10)

        edge              = String(get(["sidebar","edge"], "left")).trim().toLowerCase()
        edgeWidth         = parseInt(get(["sidebar","edgeWidth"], 8), 10)
        edgeCornerRadius  = parseInt(get(["sidebar","edgeCornerRadius"], 20), 10)
        sidebarWidth      = parseInt(get(["sidebar","sidebarWidth"], 300), 10)
        hoverCloseDelayMs = parseInt(get(["sidebar","hoverCloseDelayMs"], 300), 10)

        const ebs = get(["sidebar","edgeByScreen"], ({}))
        edgeByScreen = (ebs && typeof ebs === "object") ? ebs : ({})

        const lm = get(["bar","leftModules"], [])
        const cm = get(["bar","centerModules"], [])
        const rm = get(["bar","rightModules"], [])

        leftModules   = Array.isArray(lm) ? lm : []
        centerModules = Array.isArray(cm) ? cm : []
        rightModules  = Array.isArray(rm) ? rm : []

        hydrating = false
        loaded = true
    }

    property string bg: "#0B0B0B"
    property string bg2: "#1A1A1A"
    property string fg: "#E6E6E6"
    property string text: "#E6E6E6"
    property string muted: "#A8A8A8"
    property string accent: "#B80000"
    property string borderColor: "#2A2A2A"
    property real opacity: 1.0

    property int barHeight: 35
    property int pad: 20
    property int fontSize: 12
    property int radius: 12
    property int animMs: 40

    onBgChanged:          if (loaded && !hydrating) setPath(["appearance","bg"], String(bg))
    onBg2Changed:         if (loaded && !hydrating) setPath(["appearance","bg2"], String(bg2))
    onFgChanged:          if (loaded && !hydrating) setPath(["appearance","fg"], String(fg))
    onTextChanged:        if (loaded && !hydrating) setPath(["appearance","text"], String(text))
    onMutedChanged:       if (loaded && !hydrating) setPath(["appearance","muted"], String(muted))
    onAccentChanged:      if (loaded && !hydrating) setPath(["appearance","accent"], String(accent))
    onBorderColorChanged: if (loaded && !hydrating) setPath(["appearance","borderColor"], String(borderColor))
    onOpacityChanged:     if (loaded && !hydrating) setPath(["appearance","opacity"], opacity)

    onBarHeightChanged: if (loaded && !hydrating) setPath(["appearance","barHeight"], barHeight)
    onPadChanged:       if (loaded && !hydrating) setPath(["appearance","pad"], pad)
    onFontSizeChanged:  if (loaded && !hydrating) setPath(["appearance","fontSize"], fontSize)
    onRadiusChanged:    if (loaded && !hydrating) setPath(["appearance","radius"], radius)
    onAnimMsChanged:    if (loaded && !hydrating) setPath(["appearance","animMs"], animMs)

    property string edge: "left"
    property int edgeWidth: 8
    property int edgeCornerRadius: 20
    property int sidebarWidth: 300
    property int hoverCloseDelayMs: 300
    property var edgeByScreen: ({})

    onEdgeChanged:              if (loaded && !hydrating) setPath(["sidebar","edge"], String(edge).trim().toLowerCase())
    onEdgeWidthChanged:         if (loaded && !hydrating) setPath(["sidebar","edgeWidth"], edgeWidth)
    onEdgeCornerRadiusChanged:  if (loaded && !hydrating) setPath(["sidebar","edgeCornerRadius"], edgeCornerRadius)
    onSidebarWidthChanged:      if (loaded && !hydrating) setPath(["sidebar","sidebarWidth"], sidebarWidth)
    onHoverCloseDelayMsChanged: if (loaded && !hydrating) setPath(["sidebar","hoverCloseDelayMs"], hoverCloseDelayMs)
    onEdgeByScreenChanged:      if (loaded && !hydrating) setPath(["sidebar","edgeByScreen"], edgeByScreen)

    property var leftModules: []
    property var centerModules: []
    property var rightModules: []

    onLeftModulesChanged:   if (loaded && !hydrating) setPath(["bar","leftModules"], leftModules)
    onCenterModulesChanged: if (loaded && !hydrating) setPath(["bar","centerModules"], centerModules)
    onRightModulesChanged:  if (loaded && !hydrating) setPath(["bar","rightModules"], rightModules)

    function setBarEnabled(section, k, on) {
        const prop = section + "Modules"
        const arr = (root[prop] || [])
        root[prop] = arr.map(e => (e.key === k ? ({ key: e.key, enabled: !!on }) : e))
    }

    Component.onCompleted: reload()
}
