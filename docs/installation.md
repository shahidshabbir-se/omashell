# Installing Omashell

Omashell runs on Linux with Wayland and Hyprland. It is a Quickshell configuration, not a replacement for Hyprland. The shell can be installed per-user from a checkout or declaratively with Nix/Home Manager.

## User install (non-Nix)

Install Quickshell, Hyprland, `jq`, Python 3, and the Omasnap build dependencies with your distribution's package manager. Omasnap requires CMake, Make, a C++23 compiler, `pkg-config`, `wayland-scanner`, Qt 6.8 development packages (including Qt Test), LayerShellQt, Wayland development files and protocols, and libdeflate. The installer also uses `curl`, `jq`, and `tar` to fetch its latest release source. If `omasnap` is already on `PATH`, the installer reuses it and does not need the Omasnap build dependencies. Then, from a checkout:

```sh
./install.sh --check
./install.sh
```

This copies the shell to `${XDG_DATA_HOME:-~/.local/share}/omashell` and creates `~/.local/bin/omashell`. Add `~/.local/bin` to `PATH` if needed. To update, pull the checkout and rerun `./install.sh`. To uninstall, run `./install.sh --uninstall`; user settings and runtime state are preserved.

Optional widgets need additional system tools. The dependency check lists them. Network features need NetworkManager (`nmcli`); the QR share action additionally needs `qrencode` and `ip`. Audio controls need PipeWire/WirePlumber (`wpctl`) and `pactl`; the visualizer needs `cava`; battery information uses UPower; profile controls use `powerprofilesctl`; Bluetooth controls use `bluetoothctl`; weather and city search need `curl`. Screenshot capture uses Omasnap: the installer builds the latest Omasnap release into its managed user install when no `omasnap` command is already available.

To have the installer create and enable a user service:

```sh
./install.sh --enable-service --target graphical-session.target
```

Use a session target that exists in your setup, such as `hyprland-session.target`. To remove only the Omashell-managed service:

```sh
./install.sh --disable-service
```

The installer does not install distribution packages or edit Hyprland configuration. `./bin/omashell` runs directly from a development checkout.

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

## Screenshot helpers

```sh
omashell-screenshot [smart|region|windows|fullscreen|scroll] [copy|save]
omashell-open-screenshot [image]
omashell-open-screenshot --edit [image]
omasnap [--capture-region|--capture-window|--capture-fullscreen|--scroll]
```

The opener selects the newest image from `OMASNAP_SCREENSHOT_DIR` or `~/Pictures/Screenshots` when no path is supplied. `--edit` opens it in Omasnap; viewing uses `xdg-open`.
