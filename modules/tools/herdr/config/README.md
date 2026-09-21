<!-- markdownlint-disable MD013 -->

# herdr keybindings

All keybindings currently active in [`config.toml`](./config.toml). Prefix
key is `ctrl+a` — prefix-mode bindings mean "press `ctrl+a`, release, then
press the key."

Every binding not listed here is unset (commented out in `config.toml`).
Uncomment and set a key there to enable it; run `herdr server reload-config`
(or `herdr plugin action invoke sync --plugin herdr-lazy` for plugin
installs) to pick up changes without a full rebuild.

## Built-in

| Key               | Action                                     |
| ----------------- | ------------------------------------------ |
| `prefix+a`        | Cycle to the next agent in the sidebar     |
| `prefix+shift+a`  | Cycle to the previous agent in the sidebar |
| `prefix+alt+1..9` | Jump straight to agent 1-9                 |

## Plugins

| Key              | Plugin                                                              | Action                    |
| ---------------- | ------------------------------------------------------------------- | ------------------------- |
| `prefix+p`       | [herdr-plus](https://github.com/cloudmanic/herdr-plus)              | Open projects picker      |
| `prefix+f`       | [herdr-file-viewer](https://github.com/smarzban/herdr-file-viewer)  | Open file viewer in split |
| `prefix+shift+h` | [herdr-hunk-diff](https://github.com/jhochenbaum/herdr-hunk-diff)   | Review changes            |
| `prefix+shift+s` | herdr-hunk-diff                                                     | Send review to agent      |
| `prefix+shift+c` | herdr-hunk-diff                                                     | Review the last commit    |
| `prefix+shift+z` | [herdr-snooze](https://github.com/mrolafsson/herdr-snooze)          | Snooze or wake agent      |
| `prefix+alt+z`   | herdr-snooze                                                        | Toggle snoozed view       |
| `prefix+alt+r`   | [herdr-agent-quota](https://github.com/levi-qiao/herdr-agent-quota) | Refresh agent quotas      |
| `prefix+shift+q` | herdr-agent-quota                                                   | Open quota settings       |

The `herdr-hunk-diff` block in `config.toml` is managed by the plugin's own
`setup-keys` command — edit it there, not by hand.

## Installed plugins without bindings

Listed in [`plugins.list`](./plugins.list) and synced by `herdr-lazy`
([design doc](../../../../docs/superpowers/specs/2026-09-01-herdr-plugin-management-design.md)):

- [pj-herdr](https://github.com/josephschmitt/pj-herdr) — no keybinding configured yet
