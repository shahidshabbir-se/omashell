---
name: add-bar-widget
description: Add a widget to the Quickshell bar, including registration, configuration, and optional panel wiring.
---

1. Inspect `common/Widget.qml`, a comparable widget under `modules/bar/widgets/`, and the bar's loader before implementing the widget. Preserve the injected `widgetId` and `settings` contract.
2. Register the widget ID and component URL in `modules/bar/WidgetRegistry.qml`; add it to `config/shell.json` if it should appear by default. Unknown IDs silently produce an empty loader.
3. If the widget has a panel, inspect comparable panels and wire its instance and ID into `shell.qml`, including panel closing and switching behavior and IPC if needed.
4. Run relevant existing tests, including `node modules/bar/widgets/bluetooth/Model.test.js` for Bluetooth model changes. For live checks, account for `launch.sh` side effects and the active Hyprland desktop; report any checks not performed.
