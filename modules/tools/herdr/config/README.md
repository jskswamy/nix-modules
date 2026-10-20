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

| Key              | Plugin                                                             | Action                 |
| ---------------- | ------------------------------------------------------------------ | ---------------------- |
| `prefix+p`       | [herdr-plus](https://github.com/cloudmanic/herdr-plus)             | Open projects picker   |
| `prefix+b`       | [terminal-browser](https://github.com/zenbu-labs/terminal-browser) | Open browser in split  |
| `prefix+g`       | [herdr-navigator](https://github.com/thanhdat77/herdr-navigator)   | Fuzzy jump             |
| `prefix+shift+h` | [herdr-hunk-diff](https://github.com/jhochenbaum/herdr-hunk-diff)  | Review changes         |
| `prefix+shift+s` | herdr-hunk-diff                                                    | Send review to agent   |
| `prefix+shift+c` | herdr-hunk-diff                                                    | Review the last commit |

The `herdr-hunk-diff` block in `config.toml` is managed by the plugin's own
`setup-keys` command — edit it there, not by hand.
