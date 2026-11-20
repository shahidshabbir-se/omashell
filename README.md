<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/omashell-wordmark-light.svg">
    <img src="assets/omashell-wordmark.svg" alt="Omashell" width="360">
  </picture>
</p>

<p align="center"><strong>Your desktop. Your rhythm.</strong></p>

<p align="center">The Omarchy-inspired Quickshell experience, without the whole operating system.</p>

Like Omarchy's bar and desktop controls, but prefer your own distribution and setup? Omashell brings that experience to Hyprland on NixOS and other Linux distributions, without installing Omarchy or adopting its full system configuration.

Get a configurable bar and focused panels for Wi-Fi, audio, notifications, weather, clocks, and more—while keeping your existing distribution, packages, and desktop configuration in control.

**Independent by design:** Omashell does not require Omarchy, its shell, or Omarchy-specific files and commands. It uses portable system integrations and self-contained alternatives where needed.

## A calmer command center

- **See what matters.** Workspaces, clock and calendar, weather, world clocks, and notification indicators live in a configurable bar.
- **Make quick adjustments.** Open focused panels for network connections, audio devices and streams, Bluetooth devices, battery status, and power profiles.
- **Stay in control.** Share Wi-Fi, manage DNS for the active connection, run a speed test, review notification history, or pause notifications when you need focus.
- **Shape the layout.** Arrange widgets across five bar sections and choose the bar position that works for your screen.
- **Keep your flow.** Use keyboard navigation in supported panels, stay-awake controls, an audio visualizer, and screenshot capture tools.

Some features depend on system services and optional helper tools. Omashell does not install or enable those system services for you.

## Get started

### NixOS and Home Manager

Run the flake package directly:

```sh
nix run github:shahidshabbir-se/omashell
```

For a declarative setup, import the included Home Manager module. See the [NixOS / Home Manager guide](docs/installation.md#nixos--home-manager) for configuration and optional startup. The Nix integration has not yet been build-tested in this development environment.

### Other Linux distributions

From a checkout, check what your system has and install Omashell for your user:

```sh
./install.sh --check
./install.sh
```

The installer places Omashell under `${XDG_DATA_HOME:-~/.local/share}/omashell` and adds the `omashell` command to `~/.local/bin`. It can also build and manage Omasnap for screenshot capture. Startup is opt-in; installation does not edit Hyprland configuration.

For dependencies, updates, uninstalling, and optional session startup, see the [installation guide](docs/installation.md).

## Make it yours

Your user configuration is `${XDG_CONFIG_HOME:-~/.config}/omashell/shell.json`. Without an override, Omashell uses [`config/shell.json`](config/shell.json).

Arrange widgets in `left`, `centerBegin`, `center`, `centerEnd`, and `right`; choose `top`, `bottom`, `left`, or `right` for the bar position. For example:

```json
{
  "version": 1,
  "bar": {
    "position": "top",
    "left": ["logo", "workspaces"],
    "centerBegin": [
      { "id": "indicators", "items": ["Dnd", "StayAwake"] }
    ],
    "center": ["clock"],
    "centerEnd": ["worldclock", "weather"],
    "right": ["music", "bluetooth", "network", "audio", "display", "power"]
  }
}
```

The music widget appears when an MPRIS player has active or paused playback. Existing user configurations retain their layout; add `"music"` to a bar section to enable it there.

The clipboard history picker opens from a keybind, not the bar. See [clipboard setup and shortcuts](docs/installation.md#clipboard-history).

See [`modules/bar/WidgetRegistry.qml`](modules/bar/WidgetRegistry.qml) for widget IDs. Notification and widget state is kept in your XDG state directory, not in the installed application.

## Dependencies

Omashell needs a **Wayland session running Hyprland**, plus Quickshell. For a user install, the launcher and installer also check for Bash, Python 3, `realpath`, `readlink`, `hyprctl`, `jq`, `wl-copy`, and `wl-paste`. Timezone data is used by the world clock. A Nerd Font such as JetBrainsMono Nerd Font is needed for the intended icons.

Other tools and services are only needed for the features you use:

| Feature | Dependencies |
|---|---|
| Network, Wi-Fi, and DNS | NetworkManager and `nmcli`; `ip` for network details; `qrencode` for Wi-Fi sharing |
| Audio and visualizer | PipeWire/WirePlumber (`wpctl`), `pactl`; `cava` for the visualizer |
| Bluetooth | BlueZ and `bluetoothctl` |
| Battery and power profiles | UPower; `powerprofilesctl` from power-profiles-daemon for profile controls |
| Weather and place search | `curl` and an internet connection |
| Stay awake | `systemd-inhibit` and a working systemd inhibitor service |
| Screenshots | `omasnap`; `xdg-open` to open saved images |
| Clipboard history | `wl-copy` and `wl-paste` (wl-clipboard); `wtype` for automatic paste |
| [Display settings](docs/installation.md#display-settings-panel) | `brightnessctl` for laptop brightness; Hyprland Lua configuration and `systemd-run` with a user manager for mode previews |

Notification delivery requires the shell to own the desktop notification service; another running notification daemon can prevent it from registering. The installer can build Omasnap if it is not already available; that requires additional build tools and libraries listed in the [installation guide](docs/installation.md).

Run `./install.sh --check` to check the installer's required and optional tools. The Nix package supplies many helper executables, but your system still needs the relevant services configured and running. It does not enable them for you.

## Development

Run the shell from this checkout inside a Hyprland session:

```sh
./bin/omashell
```

Check QML and Bash syntax with:

```sh
./lint.sh
```

Live testing can affect desktop state and use network services. If `omashell.service` is running, stop it before launching the checkout in the same session and start it again when finished. Only one notification server can own `org.freedesktop.Notifications` on a session bus. To run both copies, use a nested Hyprland session on a separate D-Bus session bus.
