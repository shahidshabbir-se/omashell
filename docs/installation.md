# Installing Omashell

Omashell runs on Linux with Wayland and Hyprland. It is a Quickshell configuration, not a replacement for Hyprland. The shell can be installed per-user from a checkout or declaratively with Nix/Home Manager.

## User install (non-Nix)

Install Quickshell, Hyprland, `jq`, Python 3, and the Omasnap build dependencies with your distribution's package manager. Omasnap requires CMake, Make, a C++23 compiler, `pkg-config`, `wayland-scanner`, Qt 6.8 development packages (including Qt Test), LayerShellQt, Wayland development files and protocols, and libdeflate. The installer also uses `curl`, `jq`, and `tar` to fetch its latest release source. If `omasnap` is already on `PATH`, the installer reuses it and does not need the Omasnap build dependencies. Then, from a checkout:

```sh
./install.sh --check
./install.sh
```

This copies the shell to `${XDG_DATA_HOME:-~/.local/share}/omashell` and creates `~/.local/bin/omashell`. Add `~/.local/bin` to `PATH` if needed. To update, pull the checkout and rerun `./install.sh`. To uninstall, run `./install.sh --uninstall`; user settings and runtime state are preserved.


### Wallpapers

Open the wallpaper picker with `omashell ipc call omashell toggleWallpaper` or bind that command in Hyprland. There is no bar widget. The picker shows personal and downloaded backgrounds together in one carousel. It reads `~/Pictures/Wallpapers` by default. To use a different set of files or folders, set `wallpaper.sources` in `shell.json`:

```json
{
  "wallpaper": {
    "sources": ["~/Pictures/Wallpapers", "~/Pictures/favorites/forest.jpg", "/mnt/media/backgrounds"]
  }
}
```

Use `[]` to omit personal sources. Folders are scanned one level deep. The older `wallpaper.directory` setting still works as shorthand for one local source. Browse with the arrow keys, scroll wheel, or by clicking a side preview. Press Enter or click the center preview to set it on all outputs. Install `awww` and the Qt 6 image formats plugins and start `awww-daemon` with your Wayland session if it is not already running.

**Optional Omarchy wallpapers.** The standalone installer asks whether to download them on an interactive terminal; the default is to skip. Say yes to choose themes by name or number, or choose `all`. For unattended setups:

```sh
./install.sh --omarchy-wallpapers catppuccin,tokyo-night  # or: all
./install.sh --no-omarchy-wallpapers                    # skip even on a terminal
```

The installer reads the current upstream catalog and downloads only image files from the requested themes, not themes, scripts, or videos. It saves them under `$XDG_DATA_HOME/omashell-wallpapers/omarchy` (default `~/.local/share/omashell-wallpapers/omarchy`), separate from personal files and the shell install. Run the same command again to add newly published images; previously downloaded copies are retained. It never sets the active wallpaper. The images come from [Omarchy upstream](https://github.com/omacom/omarchy); Omashell does not bundle or relicense them.

Optional widgets need additional system tools. The dependency check lists them. Network features need NetworkManager (`nmcli`); the QR share action additionally needs `qrencode` and `ip`. Audio controls need PipeWire/WirePlumber (`wpctl`) and `pactl`; the visualizer needs `cava`; battery information uses UPower; profile controls use `powerprofilesctl`; Bluetooth controls use `bluetoothctl`; weather and city search need `curl`. Screenshot capture uses Omasnap: the installer builds the latest Omasnap release into its managed user install when no `omasnap` command is already available.

To have the installer create and enable a user service:

```sh
./install.sh --enable-service --target graphical-session.target
```

Use a session target that exists in your setup, such as `hyprland-session.target`. To remove only the Omashell-managed service:

```sh
./install.sh --disable-service
```

The installer does not install distribution packages. On Arch Linux and other standalone installs, it adds a marked Display include to an existing, local `hyprland.lua` and configures Omashell to use it. Pass `--no-display-integration` to leave Hyprland untouched. The installer skips symlinked configs, existing explicit display profiles, and unmanaged files with the same name. `./bin/omashell` runs directly from a development checkout.

Configuration overrides live in `${XDG_CONFIG_HOME:-~/.config}/omashell/shell.json`. If absent, Omashell uses the bundled `config/shell.json` defaults. Notification and widget state remains under `$XDG_STATE_HOME/omashell` (or `~/.local/state/omashell`).

## NixOS / Home Manager

Add the repository as a flake input and import its Home Manager module. With Home Manager integrated into NixOS:

```nix
{
  inputs.omashell.url = "github:shahidshabbir-se/omashell";
  inputs.omashell.inputs.nixpkgs.follows = "nixpkgs";

  # In the NixOS configuration:
  home-manager.sharedModules = [ inputs.omashell.homeManagerModules.default ];
  home-manager.users.yourUser.programs.omashell = {
    enable = true;
    systemd.enable = true;
    # Optional: target = "hyprland-session.target";
    # Optional: settings = { bar.right = [ "notifications" "network" "audio" "power" ]; };
  };
}
```

Or import `inputs.omashell.homeManagerModules.default` into a standalone Home Manager configuration. The module adds the package to `home.packages`; the user service is opt-in and defaults to Home Manager's Wayland session target. `settings` is written declaratively to `omashell/shell.json`.

The flake also exposes `packages.<system>.default` and supports `x86_64-linux` and `aarch64-linux`. Quickshell and Omashell's helper executables are included in the package runtime environment. Nix installs the shell under the store; do not edit that copy. Use the Home Manager settings option or the XDG config override instead.

The Nix package includes Omasnap and the Omashell screenshot clients; it provides command-line clients, not system daemons. Enable/configure NetworkManager, PipeWire/WirePlumber, UPower, Bluetooth, and Hyprland in the NixOS configuration when those features are wanted.

### Optional Omarchy wallpapers on NixOS

Add an upstream source input to your flake when you want these wallpapers. The lock file pins the revision; the input is not needed for personal sources.

```nix
# flake.nix inputs
inputs.omarchy-wallpapers = {
  url = "github:omacom/omarchy";
  flake = false;
};

# Home Manager user configuration, with your flake inputs in scope
programs.omashell.wallpaper.omarchy = {
  enable = true;
  source = inputs.omarchy-wallpapers.outPath;
  themes = [ "catppuccin" "tokyo-night" ]; # omit or set null for all themes
};
```

Nix fetches the pinned source, but Omashell only lists the selected directories' image files and never runs any Omarchy code. To refresh the source, run `nix flake update omarchy-wallpapers` in your configuration and rebuild. An applied image from the Nix store is copied to user data so garbage collection cannot remove your active wallpaper.

## Screenshot helpers

```sh
omashell-screenshot [smart|region|windows|fullscreen|scroll] [copy|save]
omashell-open-screenshot [image]
omashell-open-screenshot --edit [image]
omasnap [--capture-region|--capture-window|--capture-fullscreen|--scroll]
```

The opener selects the newest image from `OMASNAP_SCREENSHOT_DIR` or `~/Pictures/Screenshots` when no path is supplied. `--edit` opens it in Omasnap; viewing uses `xdg-open`.

## Clipboard history

The clipboard picker is opened with a keybind, not a bar widget. To opt in to recording, add `"clipboard": { "enabled": true }` at the top level of `${XDG_CONFIG_HOME:-~/.config}/omashell/shell.json` (Home Manager: `programs.omashell.settings.clipboard.enabled = true;`). If you have no existing config, this is enough:

```json
{ "clipboard": { "enabled": true } }
```

Add **Super+Ctrl+V** in your Hyprland config's format:

```ini
bind = SUPER CTRL, V, exec, omashell ipc call omashell toggleClipboard
```

```lua
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("omashell ipc call omashell toggleClipboard"))
```

Type to search the previews. Click **All**, **Text**, **Links**, **Colors**, **Images**, or **Files** to filter by type, or cycle through filters with **Tab** and **Shift+Tab**. Standalone CSS hex colors show a swatch in the list and preview without changing what gets pasted.

Use **↑/↓** or **Ctrl+K/Ctrl+J** to select, and press **Enter** or click to paste. **Shift+Enter** copies without pasting. **Delete** removes the selected entry; **Shift+Delete** opens a clear-all confirmation. **Escape** clears the search, then resets the filter, then closes the picker. Automatic paste sends **Shift+Insert** with `wtype`; if `wtype` is missing or the target doesn't support that shortcut, paste manually from the clipboard.

While clipboard history is enabled, Omashell captures text, PNG images, and `text/uri-list` file selections using `wl-clipboard`. History is local and unencrypted, stored in `${XDG_STATE_HOME:-~/.local/state}/omashell/clipboard/`, with up to 100 entries and 32 MiB of clipboard payloads. It skips clipboard offers marked sensitive, but not secrets copied by apps that omit that hint. Clear the history before disabling it if you don't want prior entries to remain on disk. Disabling history stops recording; clearing history does not clear the system clipboard.

The picker layout and shortcuts are inspired by [Omarchy's clipboard menu](https://github.com/omacom/omarchy/tree/b20d7876f5ec6a45d18b9e4383dc4b6d9e8492ab/shell/plugins/clipboard). Omashell does not use Omarchy's tools or history files.

## Display settings panel

The Display widget appears on the right by default, between Audio and Power. If you set your own `bar.right`, add `"display"` where you want it. You can also open the panel with `omashell ipc call omashell toggleDisplay`. The panel and bar icon can adjust the built-in brightness using `brightnessctl` when an unambiguous kernel backlight is available. Brightness is immediate and does not edit the profile. Scroll over the icon on the laptop display to adjust brightness in 5% steps.

Mode previews need one writable display profile. Choose the form that matches how Hyprland gets its monitor rule:

- `display.standalonePath` — a `.lua` fragment Omashell generates and updates. Hyprland loads it directly, so a saved setting survives config reloads and new sessions without NixOS. This is the option for other Linux distributions.
- `display.profilePath` — the version 1 JSON file described below, read by your Nix configuration. **Keep** saves it, and a rebuild makes it part of the NixOS generation.

When both are set, `display.standalonePath` takes precedence.

### Standalone Linux (no NixOS)

On a standard Arch Linux or other standalone installation, `./install.sh` sets up Display integration automatically if you already have a local `~/.config/hypr/hyprland.lua`. Open **Display**, preview changes, and choose **Keep**. There is no file to create or include manually. Uninstall removes the installer-managed include and leaves the saved display profile in place.

If you opted out, use a symlinked or custom Hyprland configuration, or run from the checkout without the installer, set `display.standalonePath` in `~/.config/omashell/shell.json` (merge it with any existing settings):

```json
{"display":{"standalonePath":"/home/you/.config/hypr/omashell-display.lua"}}
```

Include that dedicated file after your fallback monitor rules. Use a guarded include so the first login works before the panel creates it:

```lua
-- ~/.config/hypr/hyprland.lua
local display_path = "/home/you/.config/hypr/omashell-display.lua"
local display_file = io.open(display_path, "r")
if display_file then
  display_file:close()
  dofile(display_path)
end
```

The file does not need to exist beforehand. On first **Keep**, Omashell creates it with mode `0644`; its directory must already exist and be writable. Omashell owns the whole file and rewrites it atomically. The first line is a versioned header, followed by one generated `hl.monitor` rule:

```lua
-- omashell-display-profile: {"connector":"eDP-1","height":1080,"refreshRate":60,"scale":1.3333,"version":1,"width":1920}
hl.monitor({ output = "eDP-1", mode = "1920x1080@60.000000", position = "auto", scale = 1.333300 })
```

Do not edit that file by hand. Omashell reads the header, checks that the body exactly matches the header, and refuses to overwrite a file it does not recognize. To change settings, use the panel; to keep your own rules, include a separate file instead and leave this path unset.

Hyprland applies the fragment on startup and on `hyprctl reload`. Run a reload after **Keep** only if you need the saved rule restored immediately and the live mode was already reverted.

### NixOS / Home Manager JSON profile

With Home Manager, set `programs.omashell.settings.display.profilePath` to the checkout path **as a string**, not a Nix path value that would be copied into the store.

For example, track `hosts/nix/comet/display.json` in your dotfiles and have your Nix config read it with `builtins.fromJSON (builtins.readFile ./hosts/nix/comet/display.json)` (relative to the flake root). The version 1 format is:

```json
{
  "version": 1,
  "connector": "eDP-1",
  "width": 1920,
  "height": 1080,
  "refreshRate": 60,
  "scale": 1.3333
}
```

For an existing Home Manager configuration using `configType = "lua"`, the minimal integration is:

```nix
# In a module at the root of your dotfiles. Replace both example paths.
{ ... }:
let
  d = builtins.fromJSON (builtins.readFile ./hosts/comet/display.json);
in {
  programs.omashell.enable = true;
  programs.omashell.settings.display.profilePath = "/home/you/dotfiles/hosts/comet/display.json";
  wayland.windowManager.hyprland.settings.monitor = [{
    output = d.connector;
    mode = "${toString d.width}x${toString d.height}@${toString d.refreshRate}";
    position = "auto";
    scale = d.scale;
    transform = d.transform or 0;
  }];
}
```

Use this in place of the existing rule for that connector, not alongside it. Add the new profile to Git so a local Git flake can see it. Rebuild once to activate the integration, then rebuild after **Keep** to include the saved profile in a new NixOS generation. Keep one profile per host.

The panel supports one connected, unmirrored display at the default position, whether it is built in or external. It can rotate by 0°, 90°, 180°, or 270°; the optional `transform` field stores those values as `0` through `3`. It requires Hyprland Lua monitor control and `systemd-run` with a reachable systemd user manager; it refuses previews without an independent watchdog. VRR, flipped transforms, custom modelines, and multi-monitor layouts are not supported. Without a systemd user manager, brightness still works where `brightnessctl` does, but mode previews are unavailable. **Text size** applies to Omashell, not GTK apps or terminals.

For HDR or non-default color, set `"exactRule": true` in the writable JSON profile **only if** Hyprland already loads the color settings from an `hl.monitor` rule whose `output` exactly equals the connector (such as `DP-4`). Do not use this with a wildcard or `desc:` color rule: Hyprland only merges a monitor update when its selector exactly matches the existing rule. Keep the color fields in the Hyprland rule on rebuild; Omashell only saves the mode, scale, and rotation. The watchdog checks that the live pixel format and color settings are unchanged before confirming a preview or reporting a successful rollback.

The card layout is inspired by [Omarchy's monitor panel](https://github.com/omacom/omarchy/tree/b20d7876f5ec6a45d18b9e4383dc4b6d9e8492ab/shell/plugins/panels/monitor). The Omashell panel uses its own controls and backend and does not require Omarchy.

Selecting a scale, resolution, refresh rate, or rotation immediately previews the change and verifies it against Hyprland. **Keep** and **Revert** appear only during the preview. The watchdog restores the previous live mode on **Revert**, panel dismissal, or after 15 seconds without confirmation, including if the shell restarts. **Keep** atomically updates the profile without overwriting a detected edit made during preview. It does not rebuild, commit, or use `sudo`. In NixOS mode, rebuild to make the saved rule part of your generation; a reload or new session before then restores the previously built settings. In standalone mode, the included fragment is the saved rule.
