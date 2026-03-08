<img width="2880" height="1800" alt="screenshot" src="https://github.com/user-attachments/assets/647438a5-c7b9-4ce7-aff7-c50c290e59ee" />

# M4.Shell
A powerful yet simple UI overlay made for Hyprland, Niri, and Sway

>[!WARNING]
>This project is in early stage development

>[!NOTE]
> CURRENTLY this project has only been tested on Gentoo & Arch Linux running Hyprland & Niri, however other distros and WMs should work (if you can figure out dependencies) but are not officially supported.

# Dependencies
### Core Requirements
- `quickshell-git` (AUR)
- `hyprland` OR `niri` (Wayland WM)
- `ttf-jetbrains-mono-nerd` (for icons)
- `xdgdesktopportal` (compatibility)
- `jq` (parsing and json)
### Button Suite
- `hyprlock` OR `swaylock` (Lock PC)
- `btop` OR `htop` (Resources & Processes)
### Visual Suite
- `sunsetr` (AUR) (blue light filter)
- `brightnessctl` (brightness control)
### Audio Suite
- `pipewire`
- `pipewire-pulse`
- `wireplumber`
### Bluetooth Suite
`bluez` (Control & support bluetooth)
`bluez-utils`
### Network Suite
- `networkmanager` (Control connections)
### VPN Suite
- `wireguard-tools` (Create wireguard connections)
    - Unfortunately, it currently requires you to allow your user to use wireguard without sudo
### dGPU Suite
- `supergfxctl` (GPU Switcher)
    - Only tested on ASUS Zephyrus G14 (Feel free to test and let me know)
### Power Suite
- `upower` (Read battery values)
- `power-profiles-daemon` and/or `asusctl` (Power mode switcher(s))
#### Quick Command (AUR)
```
paru -S quickshell-git sunsetr swaylock brightnessctl wireguard-tools networkmanager bluez btop upower power-profiles-daemon ttf-jetbrains-mono-nerd pipewire pipewire-pulse wireplumber xdgdesktopportal
```
```
sudo systemctl enable --now power-profiles-daemon bluetooth networkmanager
```
# Installation (After Dependencies)
### Hyprland
1. Create new Quickshell directory:
```
mkdir ~/.config/quickshell
```
2. Move into directory:
```
cd ~/.config/quickshell
```
3. Clone the repo:
```
git clone https://tangled.org/3r.m4zy.lol/m4.shell
```
4. Test Run Quickshell with the m4.shell config:
```
QT_QPA_PLATFORMTHEME=xdgdesktopportal qs -c m4.shell
```
5. Add to Hyprland config:
```
exec-once = QT_QPA_PLATFORMTHEME=xdgdesktopportal qs -c m4.shell
```
### Niri
1. Create new Quickshell directory:
```
mkdir ~/.config/quickshell
```
2. Move into directory:
```
cd ~/.config/quickshell
```
3. Clone the repo:
```
git clone https://tangled.org/3r.m4zy.lol/m4.shell
```
4. Test Run Quickshell with the m4.shell config:
```
QT_QPA_PLATFORMTHEME=xdgdesktopportal qs -c m4.shell
```
5. Add to Niri config:
```
spawn-sh-at-startup "QT_QPA_PLATFORMTHEME=xdgdesktopportal qs -c m4.shell"
```
