# m4.shell – Codebase documentation for AI context

This file describes the m4.shell codebase and how it works. Use it as the primary context and documentation when working on this project.

## Project overview

**m4.shell** is a Wayland UI overlay for Hyprland, Niri, and Sway. It is built with [Quickshell](https://github.com/quickshell/quickshell) (Qt/QML). The project lives at **`~/.config/quickshell/m4.shell`** (or `$XDG_CONFIG_HOME/quickshell/m4.shell`). Quickshell is run with config name `m4.shell`:

```bash
qs -c m4.shell
```

The UI consists of:
- **Bar** – top panel per screen (workspaces, VPN, network, tray, Bluetooth, power, volume, clock)
- **Sidebar** – slide-out panel from a screen edge (left or right, configurable per screen) with button grid and “suites” (Visual, Volume, Bluetooth, Network, VPN, SSH, dGPU, Power)
- **Edge** – small corner opposite the sidebar edge (rounded corner visual)
- **Wallpaper** – per-screen background image, with lock-screen integration (swaylock/hyprlock)

All paths in code and scripts assume the config directory is **`~/.config/quickshell/m4.shell`** (see **Paths and conventions** below).

---

## Directory structure

```
m4.shell/
├── shell.qml              # Entry point; creates per-screen Bar, Sidebar, Wallpaper, Edge
├── config/
│   ├── Config.qml         # Root config object (appearance, sidebar, bar, wallpapers)
│   ├── BarConfig.qml      # Bar module list / reorder (wraps cfg)
│   ├── SidebarConfig.qml  # Sidebar edge, width, etc. (wraps cfg)
│   └── Appearance.qml     # Colors, sizes, animation (wraps cfg)
├── services/
│   ├── ConfigService.qml  # Load/save config.json via configctl.sh; exposes appearance/bar/sidebar
│   ├── SidebarState.qml   # Sidebar open/close/pin state and slide animation
│   ├── Wallpapers.qml     # Current wallpaper path; setWallpaper(); swaylock export
│   └── Time.qml           # Simple clock string (MM/dd hh:mm), 30s refresh
├── modules/
│   ├── bar/
│   │   ├── Bar.qml        # Top panel window; embeds bar modules
│   │   └── modules/       # VPN, Network, Volume, Power, Tray, Bluetooth, Workspaces, etc.
│   ├── sidebar/
│   │   ├── Sidebar.qml    # Edge strip + sliding panel; hover to open/close
│   │   ├── SidebarMenu.qml# Flickable content: Buttons + suite list
│   │   ├── Buttons.qml    # Quick actions (launcher, power, lock, wallpaper, settings)
│   │   └── suites/        # VisualSuite, VolumeSuite, NetworkSuite, VPNSuite, SSHSuite, etc.
│   ├── edge/
│   │   └── OppositeTopCorner.qml  # Rounded corner opposite sidebar edge
│   ├── wallpaper/
│   │   └── WallpaperWindow.qml    # Full-screen background image per screen
│   ├── settings/
│   │   └── SettingsPanel.qml      # Modal settings (appearance, sidebar, bar)
│   └── launcher/
│       └── AppLauncher.qml        # App grid/search launcher
├── scripts/               # Shell scripts; invoked by QML via Process
│   ├── configctl.sh       # config.json: dump | write | merge | reset
│   ├── swaylock.sh        # Export wallpaper to swaylock (dimmed image + config block)
│   ├── audioctl.sh        # PipeWire/wpctl volume and sinks/sources
│   ├── visualctl.sh       # Brightness, blue light (sunsetr/hyprsunset)
│   ├── networkctl.sh      # NetworkManager
│   ├── vpnctl.sh          # WireGuard
│   ├── sshctl.sh          # SSH connections/keys under ~/.config/quickshell/m4.shell/ssh
│   ├── dgpuctl.sh         # supergfxctl (GPU mode)
│   └── powerctl.sh        # Battery, power profile (upower, power-profiles-daemon, asusctl)
├── components/            # Reusable UI (e.g. controls/StyledText.qml)
├── utils/
│   ├── Format.js          # clamp(n, lo, hi)
│   └── Anim.qml           # Animation presets (micro/standard/entry) and Behavior helpers
├── config.json            # Persistent config (appearance, sidebar, bar); edited via ConfigService
├── config.defaults.json   # Defaults for configctl reset
└── ssh/                   # SSH suite data (e.g. connections.db); .gitignore has .ssh
```

---

## Entry point and per-screen model

**`shell.qml`** is the single entry. It:

1. Creates a **Config** instance (which owns **ConfigService** and **Wallpapers**).
2. Uses **Variants** with `model: Quickshell.screens` so everything is **per screen**.
3. For each screen it creates one **Scope** containing:
   - **SidebarState** – shared sidebar open/pin state and slide value
   - **WallpaperWindow** – full-screen background for that screen
   - **Bar** – top bar for that screen
   - **Sidebar** – edge strip + sliding panel (single sidebar shared conceptually; positioned by edge)
   - **OppositeTopCorner** – rounded corner on the opposite side of the screen

So: one sidebar state per scope, one bar and one wallpaper per screen. Config is global; `config`, `sidebarState`, and `screenRef`/`screen` are passed down into Bar, Sidebar, and suites.

---

## Configuration system

### Config and ConfigService

- **`config/Config.qml`** defines the root **Config** object used everywhere. It exposes:
  - **config.cfg** – the **ConfigService** (load/save, path getters/setters).
  - **config.appearance** – colors, sizes, animation (bg, bg2, fg, text, muted, accent, borderColor, opacity, barHeight, pad, fontSize, radius, animMs).
  - **config.sidebar** – edge, edgeWidth, edgeCornerRadius, sidebarWidth, hoverCloseDelayMs, edgeByScreen; and **edgeForScreen(screenName)**.
  - **config.bar** – leftModules, centerModules, rightModules; **setBarEnabled(section, key, on)**.
  - **config.wallpapers** – Wallpapers service (current path, setWallpaper).

- **`services/ConfigService.qml`**:
  - Persists state in **config.json** under `~/.config/quickshell/m4.shell/`.
  - Load: runs **configctl.sh dump**, parses JSON, then **applyLoaded()** to set all appearance/sidebar/bar properties.
  - Save: debounced **flush()** that runs **configctl.sh write '<json>'**.
  - Uses **hydrating** to avoid writing back during load. **loaded** is true after first successful load.
  - Exposes get/setPath for nested keys and **restoreDefaults()** (configctl reset).

### configctl.sh

- **Location**: `~/.config/quickshell/m4.shell/scripts/configctl.sh`
- **Commands**: `dump` (cat config.json), `write <json>`, `merge <json>`, `reset` (copy config.defaults.json over config.json).
- **Depends**: `jq`; expects config.json and config.defaults.json to exist.

### config.json shape

- **appearance**: bg, bg2, fg, text, muted, accent, borderColor, opacity, barHeight, pad, fontSize, radius, animMs.
- **sidebar**: edge, edgeWidth, edgeCornerRadius, sidebarWidth, hoverCloseDelayMs, edgeByScreen (e.g. `{"DP-2":"right","DP-3":"left"}`).
- **bar**: leftModules, centerModules, rightModules – arrays of `{ "key": "workspaces"|"volume"|..., "enabled": true|false }`.

The **Bar** in this codebase currently **hardcodes** its modules (IconButton, ResourceDials, VPN, Network, Workspaces, Tray, Bluetooth, Power, Volume, StyledText clock). The config bar modules are used by **SettingsPanel** for enable/disable and reordering; Bar.qml does not dynamically build from config yet.

---

## Services

| Service | Purpose |
|--------|---------|
| **ConfigService** | Load/save config.json; expose appearance, sidebar, bar; path get/set. |
| **SidebarState** | `open`, `pinnedOpen`, `slide` (0..sidebarWidth); `expand()`/`collapse()`/`enterSidebar()`/`leaveSidebar()`/`togglePinned()`. Slide animation with bezier curves. |
| **Wallpapers** | `current` path, `setWallpaper(path)`; calls **swaylock.sh** to export wallpaper to lock screen; uses Quickshell Settings category `"m4.shell"` for persistence. |
| **Time** | `now` (MM/dd hh:mm), updated every 30s. |

---

## Modules

### Bar (`modules/bar/Bar.qml`)

- **PanelWindow**, anchored top, full width, height from **config.appearance.barHeight**.
- **WlrLayershell**: layer Top, namespace **`m4.shell:bar:<screenName>`**.
- Gets colors/opacity from config.appearance; contains:
  - Left: IconButton (sidebar pin toggle), ResourceDials, VPN, Network.
  - Center: Workspaces.
  - Right: Tray, Bluetooth, Power, Volume, StyledText (time).
- **sidebarState** used for **toggleSidebarPinned()**.

### Sidebar (`modules/sidebar/`)

- **Sidebar.qml**: Thin edge strip + sliding body. **WlrLayershell** namespace **`m4.shell:sidebar`**. Edge side from **config.sidebar.edgeForScreen(screen.name)**. Width = edgeWidth + slide + corner radius. **HoverHandler** and debounce timer drive **sidebarState.enterSidebar()** / **leaveSidebar()**. Rounded corners via MultiEffect masks.
- **SidebarMenu.qml**: Flickable column with **Buttons**, then the list of **suites** (Visual, Volume, Bluetooth, Network, VPN, SSH, dGPU, Power). Also opens **FileDialog** for wallpaper, **AppLauncher**, **SettingsPanel**.

### Suites (`modules/sidebar/suites/`)

Each suite is an **Item** with:

- **required property QtObject config**
- **property QtObject sidebarState** (optional; used for keepPanelHovered)
- **readonly property string ctl** (or similar) – path to its **\*ctl.sh** script, e.g. `$HOME/.config/quickshell/m4.shell/scripts/visualctl.sh`
- Theme colors from **config.appearance** (bg, bg2, accent/red, text, muted, borderColor)
- **Quickshell.Io Process** to run the ctl script for get/set (e.g. brightness, volume, network status)

Suites call the ctl scripts via `Process` with `command: ["sh", "-lc", root.ctl + " ..."]`. They parse stdout (often JSON or line-based) to update QML state. Pattern: **keepPanelHovered()** / **releasePanelHover()** to prevent sidebar from closing while interacting.

| Suite | Script | Main role |
|-------|--------|-----------|
| VisualSuite | visualctl.sh | Brightness, blue light (sunsetr) |
| VolumeSuite | audioctl.sh | PipeWire sinks/sources, volume, mute |
| BluetoothSuite | (bluez/bluetoothctl) | Bluetooth devices |
| NetworkSuite | networkctl.sh | NetworkManager connections |
| VPNSuite | vpnctl.sh | WireGuard; logPath e.g. /tmp/m4.shell-wg.log |
| SSHSuite | sshctl.sh | SSH keys under m4.shell/ssh, connections |
| DGPUSuite | dgpuctl.sh | supergfxctl GPU mode |
| PowerSuite | powerctl.sh | Battery, power profile |

### Edge (`modules/edge/OppositeTopCorner.qml`)

Small panel at the top, on the side **opposite** the sidebar (left or right from **config.sidebar.edgeForScreen**). Draws a rounded quarter-circle to match the sidebar corner. **ExclusionMode.Ignore** so it doesn’t reserve space.

### Wallpaper (`modules/wallpaper/WallpaperWindow.qml`)

- **PanelWindow** full screen, **WlrLayershell** layer Background, namespace **`m4.shell:wallpaper`**.
- **config.wallpapers.current** and **reloadSerial** drive image URL (with cache-bust query). Two **Image** items (imgA/imgB) for crossfade when wallpaper changes.

### Settings and Launcher

- **SettingsPanel.qml**: Modal panel; appearance (theme presets, colors), sidebar (edge, width), bar (module toggles/reorder). Reads/writes via **config.cfg** (ConfigService).
- **AppLauncher.qml**: Centered overlay with search and app grid; runs desktop apps via Process.

---

## Scripts (ctl pattern and swaylock)

### Base path

All scripts assume the project root is:

**`${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/m4.shell`**

Referred in QML as `$HOME/.config/quickshell/m4.shell` (scripts expand `$HOME` when run via `sh -lc`).

### configctl.sh

- **dump** – output config.json (ConfigService loads this).
- **write** – overwrite config.json with given JSON (ConfigService flush).
- **merge** – deep merge JSON into config.json.
- **reset** – copy config.defaults.json to config.json.

### swaylock.sh

- **Arg**: path to current wallpaper image.
- Creates a **dimmed** copy under **`$XDG_CACHE_HOME/m4.shell/`** (or `~/.cache/m4.shell/`) for lock screen.
- Injects a block into swaylock config (between `# --- m4.shell Wallpaper Start ---` and `# --- m4.shell Wallpaper End ---`) so the lock screen uses that image. Requires **jq** not; uses **awk** and optionally **magick**/ImageMagick **convert**.

### *ctl.sh pattern

- Each feature has a **\*ctl.sh** script under **scripts/**.
- QML runs it via **Process** with `["sh", "-lc", "<path-to-ctl> <subcmd> ..."]`.
- Subcommands are script-specific (e.g. audioctl status/set, visualctl set brightness/blue on|off, networkctl list, vpnctl up/down). Scripts use **jq** where JSON is needed.
- Paths in QML are typically: **`$HOME/.config/quickshell/m4.shell/scripts/<name>ctl.sh`**.

---

## Paths and conventions

- **Project root**: `~/.config/quickshell/m4.shell` (or `$XDG_CONFIG_HOME/quickshell/m4.shell`).
- **Config file**: `.../m4.shell/config.json`.
- **Scripts**: `.../m4.shell/scripts/*.sh`.
- **SSH data**: `.../m4.shell/ssh/` (e.g. connections.db; `.gitignore` includes `.ssh`).
- **Cache**: `$XDG_CACHE_HOME/m4.shell` (e.g. swaylock dimmed wallpapers).
- **Layer-shell namespaces**: `m4.shell:bar:<screen>`, `m4.shell:sidebar`, `m4.shell:wallpaper`.
- **Quickshell Settings** (wallpaper path): category **`m4.shell`**.

When adding new scripts or paths, keep using **m4.shell** and the same base directory so everything stays consistent.

---

## Key files quick reference

| File | Role |
|------|------|
| shell.qml | Entry; Variants over screens; creates Config, SidebarState, WallpaperWindow, Bar, Sidebar, OppositeTopCorner per screen |
| config/Config.qml | Root config object (cfg, appearance, sidebar, bar, wallpapers) |
| services/ConfigService.qml | config.json load/save via configctl; appearance/sidebar/bar state |
| services/SidebarState.qml | Sidebar slide, open, pinned, expand/collapse/enter/leave/togglePinned |
| services/Wallpapers.qml | current path, setWallpaper(), swaylock export |
| modules/bar/Bar.qml | Top bar; hardcoded left/center/right modules |
| modules/sidebar/Sidebar.qml | Edge + sliding panel; hover logic |
| modules/sidebar/SidebarMenu.qml | Buttons + suite list; wallpaper dialog, launcher, settings |
| modules/sidebar/Buttons.qml | Power/lock/reboot/wifi/btop/wallpaper/settings buttons |
| modules/sidebar/suites/*.qml | Each has config, sidebarState, ctl path; runs *ctl.sh via Process |
| scripts/configctl.sh | dump | write | merge | reset for config.json |
| scripts/swaylock.sh | Export wallpaper to swaylock config; cache under m4.shell |

---

## Adding new features (for AI)

1. **New sidebar suite**: Add a new `*Suite.qml` in `modules/sidebar/suites/` with `config`, `sidebarState`, and a `ctl` path to a new or existing script. Add the suite to the **Column** in **SidebarMenu.qml** (after the existing suite list). If you add a new script, use **`$HOME/.config/quickshell/m4.shell/scripts/<name>ctl.sh`** and implement subcommands that the suite will call via **Process**.
2. **New bar widget**: Add a new QML in `modules/bar/modules/` and embed it in **Bar.qml** in the appropriate Row (left/center/right). Pass **config.appearance** (or specific colors) and **screenRef** if needed.
3. **Config keys**: To persist new settings, extend **ConfigService** (applyLoaded, properties, on*Changed → setPath) and optionally **config.defaults.json** and **config/Config.qml** (if you expose a new config subtree).
4. **Scripts**: Keep scripts under **scripts/**; use the same project base path; prefer **bash** with **set -euo pipefail**; use **jq** for JSON when the QML side expects it.
5. **Naming**: Use **m4.shell** in namespaces, paths, and comments (not MazyShell or mazyshell).

Use this document as the single source of truth for architecture and conventions when editing or extending m4.shell.
