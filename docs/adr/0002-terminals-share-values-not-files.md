# ADR 0002: Terminals share values, not config files

- Status: Accepted
- Date: 2026-11-08

## Context

Four terminal apps are configured here. Ghostty, Rex and Herdr-app are
all built on libghostty; Alacritty has its own renderer. Herdr runs as
a text UI inside Ghostty. None of them reads another's config file, so
each module held its own copy of the same settings, and the copies had
drifted: Ghostty used +3%/+5% cell spacing while Rex used +15%/-5%,
Ghostty synthesized bold and italic while Rex turned them off,
Alacritty used 14pt on macOS, and Ghostty lacked five of Rex's prefix
keys. Nothing caught a missed copy.

Rex also binds `cmd+escape` as a global show/hide hotkey. macOS gives a
global hotkey to whichever app registers it first; any other app that
binds it fails silently.

## Decision

`modules/terminal` declares the shared values as `terminal.*` options:
font, cell spacing, bold/italic, cursor, copy on select, Option as Alt,
the action keys pressed after each app's prefix (`terminal.keys`), and
the global hotkey owner. Each tool module translates them into its own
format. This is the pattern `theme.variant` already set.

- **Every value is copied into the app's own option with `mkDefault`.**
  A plain assignment in `tools.<app>.settings` or `tools.<app>.keys`
  then replaces that one value for that app only. The shared key table
  is set per action with `mkDefault` too, so `terminal.keys.zoom = [..]`
  replaces zoom and keeps every other action.
- **Shared values go into generated side files that the hand-written
  files load**: Ghostty's `config` includes `terminal.conf`; Rex's
  `init.lua` runs `terminal.lua` when it exists. The hand-written files
  stay instant-edit links into the checkout.
- **Each app keeps its own prefix** (Ghostty `ctrl+b`, Rex `ctrl+a`),
  because Ghostty hosts Herdr, which uses `ctrl+a`.
- **`terminal.keys` owns Ghostty's and Rex's action keys only.** Herdr's
  `config.toml` stays hand-written and owns the keys of Herdr and
  Herdr-app, whose `keys.json` is generated from it.
- **One app owns the global hotkey**, chosen by `terminal.hotkey.app`.
  It defaults to Rex when Rex is enabled and to none otherwise.
- **Mistakes fail evaluation** with a message: an unknown action, one
  key given to two actions, a shared key that takes over one bound in
  the hand-written file (read from that file at evaluation time), and a
  hotkey owner that is not enabled.
- **Keys use Rex's spelling** (`-`, `shift+\`, `tab`), which Ghostty
  accepts as written.
- **The shared look is Rex's**: +15% line height, -5% character
  spacing, bold and italic off, 12pt everywhere. This was the author's
  preference; Ghostty and Alacritty changed, Rex did not.

Terminal.app is left out: it has no ligatures, splits or light/dark
profile switching, so it could only partly match.

## Considered options

- **One shared config file read by every app.** Not possible: libghostty
  is a rendering library, and each app has its own config reader.
- **Generate Ghostty's `config` and Rex's `init.lua` whole.** No include
  order to reason about, but both would become read-only and every edit,
  including Rex's ~1,200 lines of Lua, would need a rebuild.
- **Generate or patch Herdr's `config.toml`.** Generating it ends
  instant edits and breaks `herdr config reset-keys`, which writes to
  the file; patching it writes into the git checkout on every
  activation. Herdr also allows one key per action, so it could not take
  the alternate keys. Its built-in defaults already sit inside the
  shared lists, which a test records.
- **Bind the global hotkey in every app.** Which one answers would
  depend on launch order.
- **Shared values as option `default`s instead of `mkDefault`.** A user
  definition replaces an option's `default` whole, so setting one action
  would drop all the others.
- **Skip unknown or clashing keys silently.** The build never fails over
  a key, but silent drift, the original problem, returns.

## Consequences

- A shared Ghostty setting written in the hand-written `config` loses to
  `terminal.conf`, because Ghostty reads included files after the file
  that includes them. Shared Ghostty settings are changed through
  `tools.ghostty.settings` and `tools.ghostty.keys` only.
- Changing `terminal.keys` does not change Herdr or Herdr-app, and
  nothing warns that they now differ.
- Rex's preferences are rewritten on every build-switch, so a value
  changed in Rex's Settings window reverts. Nix is the only place to
  change shared values.
- Hand-written files change at once; generated files change only on
  build-switch. Build-switch before reloading Ghostty or Rex.
- Herdr-app's `settings.json` is now a read-only store file. Whether
  Herdr-app tries to save to it (for example the zoom level) is
  untested; if it does, stop managing `zoom` or make the file writable.
- Rex and Ghostty may not measure cell spacing the same way, so the
  same percentages may still look slightly different. Not yet compared
  side by side.
- Moving the hotkey to Ghostty needs macOS Accessibility permission for
  Ghostty's `global:` binding. A second, hand-written `cmd+escape`
  binding is not guarded against.
