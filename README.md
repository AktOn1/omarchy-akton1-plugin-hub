# AktOn1 Plugin Hub

One bar icon and one flyout for the AktOn1 plugins. It lists the ones you have installed, shows their settings, and installs the ones you do not have yet. The Hub bundles none of them. Every AktOn1 plugin is installed on its own and works without the Hub.

- **Scratchpads**: make several named scratchpads. Each has its own key, its own slide-in side (several different sides at once), its own frame style, its own tiling layout, and apps that start at login. The original `SUPER + S` scratchpad is there from the start. One scratchpad at most holds the fullscreen-game layer.
- **Fullscreen** (shows up when Fullscreen App Auto Workspace is installed and on): the default fullscreen layer, named Fullscreen. It has its own key, layout and apps, and you choose whether fullscreen games go there (default) or to one of your scratchpads. Mute while hidden.
- **Layout** (every scratchpad and Fullscreen): Default, Dwindle, Master, Scrolling or Monocle, set on that layer's own workspace. Default leaves Hyprland alone. A custom Lua layout can be set from the command line (`padSet <id> layout lua:<name>`).
- **Start / Restart apps** (every scratchpad and Fullscreen): starts the layer's apps now, or closes the ones the Hub started there and starts them again, so you never have to restart Omarchy. Only windows the Hub itself started are closed (never a window you put there yourself, never a game).
- **More AktOn1 plugins**: plugins you have not installed yet, with an Install button. A plugin that is installed but turned off gets an Enable button.

Two modes, switched with the toggle in the flyout header (or right-click on the icon):

- **Connected**: one icon, one flyout, all settings stacked. Tooltip: "AktOn1 plugins: connected".
- **Separated**: one icon and flyout per plugin. Tooltip: "Scratchpads: AktOn1 plugin, disconnected".

## Install

```bash
omarchy plugin add https://github.com/AktOn1/omarchy-plugin-hub.git --enable
```

Then add "AktOn1 Plugins" to your bar (it is added to the right side when you enable it). Plugins are added disabled by default; `--enable` turns it on right away.

## Requirements

- Omarchy 4.x with the shell plugin system (tested on Omarchy 4.0.4, Hyprland 0.56 with Lua config).
- `hyprctl` with `eval` support, `uwsm-app` (both ship with Omarchy). The other AktOn1 plugins are optional.

## Your own keybindings

The Hub reads `~/.config/hypr/bindings.lua` and never changes it. If you already bound a key for a scratchpad or for the fullscreen layer there, the Hub shows it as "your own binding" and keeps it ("Keep my binding" is the default). The Hub then registers no key of its own for that scratchpad, so the slide direction of such a scratchpad stays whatever your Hyprland animation says. Turn "Keep my binding" off to let the Hub's key take over, and delete your line yourself if you want it gone.

Every key you pick is checked against what Hyprland has bound (`hyprctl binds`) and against the Hub's own keys. A key that is taken is refused with the name of the owner. Press a key combination in the key field to set it, Esc cancels.

## Command line

The flyout is only a face for these commands (`omarchy-shell akton1-hub ...`), so everything can be scripted.

| Command | Effect |
|---|---|
| `state` | Everything as JSON |
| `mode connected\|separated` | Switch mode |
| `padAdd <label> [direction]` | New scratchpad (direction `bottom` `top` `left` `right`) |
| `padRemove <id>` | Remove a scratchpad (the original one stays) |
| `padSet <id> <label\|key\|moveKey\|direction\|style\|keepMine\|layout> <value>` | Change one setting (`layout`: `default` `dwindle` `master` `scrolling` `monocle` `lua:<name>`) |
| `appAdd <id> <command>` / `appRemove <id> <index>` | Apps started at login |
| `appsRestart <id>` / `appsStart <id>` | Close the apps the Hub started on that layer and start them again / start them only if none are open |

The id `fullscreen` is the Fullscreen layer (it takes `layout`, `appAdd`, `appRemove`, `appsRestart`, `toggle`; its key is `fullscreenKey`).
| `magnet <id\|none>` | Scratchpad that holds the fullscreen games |
| `fullscreenKey <keys\|none>` | Key for the fullscreen layer |
| `toggle <id>` | Show or hide a scratchpad |
| `install <plugin id>` | Install (or enable) one of the AktOn1 plugins |
| `refresh` | Re-read plugins, bindings and Hyprland state |

The plugins have their own small CLIs that the Hub uses: `omarchy-shell scratchpad-frame state|pads|padsSet`, `omarchy-shell fullscreen-app-auto-workspace state|option`.

## Permissions and behavior

- Runs Lua inside Hyprland (`hyprctl eval` of the bundled `hub.lua`): registers the scratchpad keys at runtime (`hl.bind`), and it sets each layer's tiling layout with a workspace rule on its own special workspace (Default clears it again, removing the Hub gives it back), and for scratchpads that slide in from another side it sets the `specialWorkspaceIn/Out` animation style just before the toggle and puts your own value back right after. It re-registers everything after a Hyprland config reload and removes everything when the Hub stops.
- Reads `~/.config/hypr/bindings.lua` and `hyprctl -j binds` and `-j animations`. Never writes a Hyprland config file.
- Starts your "apps at login" with `uwsm-app -- <command>`, once per Hyprland session (a marker file in `$XDG_RUNTIME_DIR/akton1-hub`), or on demand with Start / Restart. It remembers which windows it started (window addresses, in `$XDG_RUNTIME_DIR/akton1-hub/owned.json`, read with `hyprctl -j clients`) and closes only those on Restart, with a normal close request. With apps on the Fullscreen layer, the Hub sets `keepOthers` in Fullscreen App Auto Workspace so those apps are not sent back to your normal workspace.
- Writes `~/.local/state/akton1-hub/state.json` (your settings), `$XDG_RUNTIME_DIR/akton1-hub/snapshot.json` (what the bar icon reads), and pushes pads and the fullscreen layer to the other AktOn1 plugins through their CLIs, only when they are installed and on.
- Network: only when you press Install, which runs `omarchy plugin add <repo> --enable --yes` for a plugin in the built-in list (the AktOn1 GitHub repositories). No telemetry.

## Update / Remove

```bash
omarchy plugin update io.github.akton1.hub
omarchy plugin remove io.github.akton1.hub
```

Removing the Hub drops its keys and leaves the other plugins as they are. Their own settings files stay, so they keep working. Delete `~/.local/state/akton1-hub` for a clean slate.

## Troubleshooting

- A key does nothing: run `hyprctl binds | grep "AktOn1 Hub"`. If it is missing, `journalctl --user -b | grep akton1-hub` shows why `hyprctl eval` failed.
- A scratchpad key you set in the Hub is refused: another binding owns it, pick another.

## License

MIT
