# AktOn1 Plugin Hub

<a href='https://ko-fi.com/akton1' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://storage.ko-fi.com/cdn/kofi3.png?v=6' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

One bar icon and one flyout for the AktOn1 plugins. It lists the ones you have installed, shows their settings, and installs the ones you do not have yet. The Hub bundles none of them. Every AktOn1 plugin is installed on its own and works without the Hub.

- **Scratchpads**: make several named scratchpads. Each has its own key, its own slide-in side (several different sides at once), its own frame style, its own tiling layout, and apps that start at login. The original `SUPER + S` scratchpad is there from the start. One scratchpad at most holds the fullscreen-game layer.
- **Fullscreen** (shows up when Fullscreen App Auto Workspace is installed and on): the default fullscreen layer, named Fullscreen. It looks like any scratchpad card (a name box you can edit, key, layout, apps), and each layer or scratchpad card has a "Fullscreen games land here" switch. Only one can be on (the others are greyed out until you switch it off; with none on, games are not moved by themselves). The "Mute the game while the layer is hidden" switch appears below the one that is on.
- **Layout** (every scratchpad and Fullscreen): Default, Dwindle, Master, Scrolling or Monocle, set on that layer's own workspace. Default leaves Hyprland alone. A custom Lua layout can be set from the command line (`padSet <id> layout lua:<name>`).
- **Start / Restart apps** (every scratchpad and Fullscreen): starts the layer's apps now, or closes the ones the Hub started there and starts them again, so you never have to restart Omarchy. Only windows the Hub itself started are closed (never a window you put there yourself, never a game).
- **Settings (gear icon in the flyout header)**: a second page with everything about the plugins themselves. *Bar icons*: "All in one icon" (connected) or "One icon each" (separated). *AktOn1 plugins*: one entry per plugin (the Hub's own Scratchpads, Scratchpad Frame, Fullscreen App Auto Workspace, Ask Me While Testing), each with an info bubble saying what it does. For an installed plugin with an icon you can switch **Connected** (inside the Hub icon) off to give it its own icon, and then choose whether that icon shows in the bar at all. A plugin that is not installed shows an **Install** button, its **Omarchy store** and **GitHub** links and the install command with a **Copy** button; an installed-but-off plugin shows **Enable**. Plugins that are not installed never get an icon or a pane. The bar always keeps at least one icon, so the gear stays reachable.

- **Ask Me While Testing** (command-line plugin, no icon): lets an AI agent that changes your desktop show a TESTING banner and ask you one-key questions (`htm`). Experimental: agents can also ask a plain question outside a test (off by default, `htm settings set questions on`). The Hub lists it in the settings page and installs it; its settings are on the command line (`htm settings`).

The two switches combine freely, so you can have the Hub icon for most plugins and a separate icon for just one. "All in one icon" and "One icon each" set every plugin at once; right-click on an icon does the same.

- **Connected** plugin: lives in the Hub icon's flyout. Tooltip: "AktOn1 plugins: connected".
- **Separate** plugin: its own icon and flyout. Tooltip: "Scratchpads: AktOn1 plugin, disconnected".

## Install

```bash
omarchy plugin add https://github.com/AktOn1/omarchy-akton1-plugin-hub.git --enable
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
| `mode connected\|separated` | Connect or separate every plugin at once |
| `separate <scratchpads\|fullscreen> <on\|off>` | Give one plugin its own icon (`on`) or put it back in the Hub icon (`off`) |
| `barShow <scratchpads\|fullscreen> <on\|off>` | Show or hide the icon of a separated plugin |
| `padAdd <label> [direction]` | New scratchpad (direction `bottom` `top` `left` `right`) |
| `padRemove <id>` | Remove a scratchpad (the original one stays) |
| `padSet <id> <label\|key\|moveKey\|direction\|style\|keepMine\|layout> <value>` | Change one setting (`layout`: `default` `dwindle` `master` `scrolling` `monocle` `lua:<name>`) |
| `appSearch <words>` | Installed apps matching the words, as `app:<id>` entries |
| `appAdd <id> <app:id\|command>` / `appRemove <id> <index>` | Apps started at login (`app:<id>` comes from the search; a plain command also works) |
| `appsRestart <id>` / `appsStart <id>` | Close the apps the Hub started on that layer and start them again / start them only if none are open |

The id `fullscreen` is the Fullscreen layer (it takes `label` (its name), `layout`, `appAdd`, `appRemove`, `appsRestart`, `toggle`; its key is `fullscreenKey`).
| `magnet <id\|none\|off>` | Where fullscreen games land: a scratchpad id, `none` = the Fullscreen layer (default), `off` = nowhere (games are not moved by themselves) |
| `fullscreenKey <keys\|none>` | Key for the fullscreen layer |
| `toggle <id>` | Show or hide a scratchpad |
| `install <plugin id>` | Install (or enable) one of the AktOn1 plugins |
| `refresh` | Re-read plugins, bindings and Hyprland state |

The plugins have their own small CLIs that the Hub uses: `omarchy-shell scratchpad-frame state|pads|padsSet`, `omarchy-shell fullscreen-app-auto-workspace state|option`.

## Permissions and behavior

- Runs Lua inside Hyprland (`hyprctl eval` of the bundled `hub.lua`): registers the scratchpad keys at runtime (`hl.bind`), and it sets each layer's tiling layout with a workspace rule on its own special workspace (Default clears it again, removing the Hub gives it back), and for scratchpads that slide in from another side it sets the `specialWorkspaceIn/Out` animation style just before the toggle and puts your own value back right after. It re-registers everything after a Hyprland config reload and removes everything when the Hub stops.
- Reads `~/.config/hypr/bindings.lua` and `hyprctl -j binds` and `-j animations`. Never writes a Hyprland config file.
- Starts your "apps at login" with `uwsm-app -- gtk-launch <app>.desktop` for apps picked from the search (terminal apps like cliamp get their terminal, as in Omarchy's launcher) or `uwsm-app -- <command>` for typed commands (a bare command that is a terminal app is switched to its desktop entry). If fewer windows open than apps are listed, the flyout says so, once per Hyprland session (a marker file in `$XDG_RUNTIME_DIR/akton1-hub`), or on demand with Start / Restart. It remembers which windows it started (window addresses, in `$XDG_RUNTIME_DIR/akton1-hub/owned.json`, read with `hyprctl -j clients`) and closes only those on Restart, with a normal close request. With apps on the Fullscreen layer, the Hub sets `keepOthers` in Fullscreen App Auto Workspace so those apps are not sent back to your normal workspace.
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

## Support

Free and MIT licensed. If it is useful to you and you want to say thanks, you can [buy me a coffee on Ko-fi](https://ko-fi.com/akton1). Totally optional.
