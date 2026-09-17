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
  inputs.nix-modules.url = "github:jskswamy/nix-modules";

  # ... in a home-manager configuration:
  imports = [
    inputs.nix-modules.homeManagerModules.shell
    inputs.nix-modules.homeManagerModules.terminal
  ];
}
```

Take `homeManagerModules.default` for everything, or individual groups for a
subset. Nothing is pulled in that you did not import.

## Modules

| Module | Contents |
| --- | --- |
| `shell` | fish, zsh, starship, direnv |
| `terminal` | alacritty, ghostty, tmux (oh-my-tmux), tmuxp |
| `editor` | neovim (LazyVim), vim, zed |
| `git-tools` | git, lazygit, gpg, tig, hunk, nbdime, related scripts |
| `agent-tools` | herdr, MCP/agentgateway, ccstatusline, beads, fabric, pet |
| `ssh` | ssh client defaults |
| `theme` | the `theme.variant` option every themeable tool reads |
| `common` | the `nixModules.sourceRoot` option |

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
