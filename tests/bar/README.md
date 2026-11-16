# Bar verification

These tests are independent of the bar widgets' implementation files. They
never write to the user's live `~/.config` or state, and they do not claim
visual parity. A passing run only proves model and wiring contracts; bar
surface geometry, anchors, tooltips, animations, and drags still need
interaction evidence.

## Offscreen runtime

```sh
./tests/bar/runtime/run-integration.sh
```

This starts a disposable Quickshell config root whose `qs.common`,
`qs.config`, and `qs.modules` point at this checkout. `HOME`,
`XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_RUNTIME_DIR` are temporary,
`WAYLAND_DISPLAY`/`HYPRLAND_INSTANCE_SIGNATURE` are unset, and
`QT_QPA_PLATFORM=offscreen` is used.

It covers:

- `BarSection` -> `WidgetRegistry` -> `Clock`/`Indicators` loading.
- Config `settings`, `widgetId`, `bar`, and `fixedEdge` injection.
- Horizontal and vertical `BarSection` sizing.
- Horizontal/vertical indicator slots and actual Nerd Font painted bounds.
- `Clock.cycleFormat()` -> `Config.setWidgetSetting()` -> re-rendered label.

PanelWindow-backed `Bar` and `PanelShell` cannot be instantiated with the
offscreen backend ("No PanelWindow backend loaded"). Those require a
disposable Wayland session; do not use the live desktop for that.

## Stay-awake lifecycle

```sh
./tests/bar/runtime/run-stay-awake-lifecycle.sh
```

This runs a fake `systemd-inhibit` that delays its SIGTERM exit and
re-enables stay-awake while the old inhibitor is still stopping. It checks
that the old process's exit does not clear the new active state and that one
replacement inhibitor is running. It uses only the fake binary and a
disposable state directory.

## Other contracts

```sh
bash config/tests/run-config-persistence-tests.sh
node common/PanelShell.test.js
node modules/bar/BarModel.test.js
node modules/bar/widgets/indicators/Model.test.js
./lint.sh
```

## Interaction/visual method

Run Omashell and the Omarchy reference in a disposable Wayland session
(nested headless compositor or VM), not on the live desktop. Use separate
`HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `XDG_RUNTIME_DIR`, and
`HYPRLAND_INSTANCE_SIGNATURE`.

1. Launch with a minimal temp `shell.json` for each edge (`top`, `bottom`,
   `left`, `right`); record the temp config before and after every action.
2. Capture the bar and adjacent desktop with `grim`/compositor screenshot;
   compare same-size crops against the reference.
3. Exercise, in both horizontal and vertical bars:
   - clock left/right/middle clicks, hover tooltip, calendar panel anchor;
   - indicator reveal on bar hover, inactive click, DND and stay-awake state;
   - open-panel marker on each edge;
   - widget drag within a section, across sections, off-bar removal;
   - empty-bar drag/click-and-hold to each edge.
4. Verify config changes land only in the disposable config and survive a
   restart; verify the inhibitor/state file after toggling stay-awake.
5. Attach screenshots/video and the before/after config to the result. No
   parity claim without that evidence.
