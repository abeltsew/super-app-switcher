# super-app-switch

A centered live-preview window switcher for Omarchy. Hold Super and tap Tab to browse open windows across workspaces, then release Super to switch.

## Controls

- **Super+Tab**: open and cycle forward.
- **Shift+Tab** while holding Super: cycle backward.
- **Click a preview**: activate that window.
- **Click ×** in a preview's upper-right corner: request that window close.
- **W** while the switcher is open: request the selected window close.
- **Release Super** or **Enter**: activate the selected window.
- **Esc**: cancel.

Closing affects one window, not every window belonging to that application. Normal save prompts are preserved. The card stays until the window actually closes. Repeated key events are ignored to avoid closing several windows by holding W.

## Requirements

Omarchy with the Quickshell shell plugin system and Hyprland Lua configuration (Quattro). Requires Quickshell Wayland Toplevel.close(), ScreencopyView, and the Hyprland integration. No extra packages are required on the development machine. Older Omarchy releases using Hyprland .conf files are not supported by the included bindings.

## Install

Install from the public repository:

```sh
omarchy plugin add https://github.com/abeltsew/super-app-switcher.git --enable
```

Add this line to `~/.config/hypr/bindings.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/omarchy/plugins/abeltsew.super-app-switch/bindings.lua")
```

Then run:

```sh
hyprctl reload
hyprctl configerrors
```

These bindings replace Super+Tab / Super+Shift+Tab workspace switching. Review conflicts with your personal shortcuts first. Installation does not modify Hyprland configuration automatically.

### Migrating from the original standalone app-switcher

Remove its `quickshell -c app-switcher --no-duplicate` autostart line and the old app-switcher binding block (including its submap and Super-release bindings) before loading the new bindings. Stop only that old Quickshell instance. Do not run both switchers with the same shortcuts.

## Development

The entry point is `Switcher.qml`; Omarchy hosts it as an overlay. `manifest.json` declares the plugin and keeps it loaded for low-latency keyboard IPC. `bindings.lua` contains the optional Hyprland integration.

```sh
omarchy plugin validate .
```

For local installation, copy this repository's files into `~/.config/omarchy/plugins/abeltsew.super-app-switch/`, then run `omarchy-shell shell rescanPlugins` and `omarchy plugin enable abeltsew.super-app-switch`. Add the bindings as above. No separate autostart process is needed.

## Remove

Remove the `dofile(...)` line from your Hyprland bindings and reload Hyprland **before** removing or disabling the plugin:

```sh
hyprctl reload
hyprctl configerrors
omarchy plugin remove abeltsew.super-app-switch
```

If recovering from an interrupted switcher, reset the active submap with `hyprctl dispatch 'hl.dsp.submap("reset")'`.

## Publishing

Before marketplace submission, optionally add a preview screenshot. The author and plugin namespace currently use the local Git identity, `abeltsew`. Submit the public repository at https://plugins.omarchy.org/publish.html.

## License

[MIT](LICENSE) — Copyright (c) 2026 abeltsew.
