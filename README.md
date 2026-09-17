# nix-modules

Composable [home-manager](https://github.com/nix-community/home-manager)
modules for per-tool configuration — shell, editors, terminals, git tooling
and AI agent tooling — each usable on its own.

Built to be shared between a daily-driver machine configuration and
disposable cloud dev boxes, so both get the same shell, editor and terminal
setup without one depending on the other.

## Using it

```nix
{
  inputs.jskswamy.url = "github:jskswamy/nix-modules";

  # ... in a home-manager configuration:
  imports = with inputs.jskswamy.homeManagerModules; [
    tools.fish
    tools.nvim
    tools.tmux
  ];
}
```

Three ways in, and they mix freely:

| Import | You get |
| --- | --- |
| `tools.<name>` | that one tool, plus anything it depends on |
| `<group>` | every tool in that group (`shell`, `terminal`, `editor`, `git-tools`, `agent-tools`, `ssh`) |
| `default` | every tool |

Importing a module is what asks for it — there is no separate `enable = true`
to remember.

### Custom groups

A group here is nothing but a file that imports some tools. Yours works the
same way, and can cut across the groups below however you like:

```nix
# my-cloud-box.nix
{
  imports = with inputs.jskswamy.homeManagerModules.tools; [
    fish
    starship
    nvim
    tmux
  ];
}
```

Import that from as many hosts as you want.

### Dependencies come along, and can be sent back

Some tools configure others. lazygit binds two keys to `hunk`; fish ships a
file that customises starship's prompt. Importing the first brings the
second with it:

```nix
imports = [ tools.lazygit ];   # hunk arrives too
```

If you did not want it, say so, and the parts that depended on it drop out
cleanly rather than breaking:

```nix
imports = [ tools.lazygit ];
tools.hunk.enable = false;     # the two `hunk show` keybindings go too
```

Every tool takes `tools.<name>.enable`, so this works for anything that
arrived indirectly.

Current edges: `fish` → `starship`, `lazygit` → `hunk`, `git` → `hunk`
(as its pager; without hunk, git keeps its own default pager).

## Groups

Each group is only a bundle of tool modules — there is nothing in a group
that is not in one of its tools.

| Group | Tools |
| --- | --- |
| `agent-tools` | `herdr`, `mcp`, `ccstatusline`, `beads`, `fabric`, `pet` |
| `editor` | `nvim`, `vim` |
| `git-tools` | `git`, `lazygit`, `gpg`, `tig`, `hunk`, `nbdime` |
| `shell` | `fish`, `zsh`, `starship`, `direnv` |
| `ssh` | `ssh` |
| `terminal` | `alacritty`, `ghostty`, `tmux`, `tmuxp` |

Per-tool detail — what each one writes, what it installs, what it brings
with it — is in **[docs/tools.md](docs/tools.md)**.

All 23 tools: `alacritty`, `beads`, `ccstatusline`, `direnv`, `fabric`, `fish`, `ghostty`, `git`, `gpg`, `herdr`, `hunk`, `lazygit`, `mcp`, `nbdime`, `nvim`, `pet`, `ssh`, `starship`, `tig`, `tmux`, `tmuxp`, `vim`, `zsh`.

`overlays.default` provides `beads`, `herdr`, `moshi-hook` and `claide`.

## Two options worth knowing

**`theme.variant`** (default `"gruvbox"`) is the one cross-cutting value.
Every themeable tool maps it to its own settings — Ghostty's capitalized
theme names, Alacritty's colorscheme file, and so on — so switching themes
is a one-line change.

**`nixModules.sourceRoot`** decides where config files come from:

- unset (default) — files are read from this flake's immutable store path.
  Hermetic, no checkout needed. This is what a disposable box wants.
- set to a local checkout of this repo — files are symlinked out of store,
  so edits take effect immediately with no rebuild. This is what a
  daily-driver config wants.

## Scope

Every value a consumer might reasonably override is wrapped in
`lib.mkDefault`, so downstream wins without editing anything here.

These modules carry no identity: no names, no email addresses, no
organization names, no absolute paths under a particular home directory.
Anything in that category belongs in the consuming configuration, layered on
top. Config that could not be written without such a value — Claude Code's
`settings.json`, for one — is deliberately not shipped here.
