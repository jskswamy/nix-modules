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
| `tools.<name>` | that one tool |
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

### Tools that work together

Some tools add lines to others. hunk sets git's pager and adds two review
keys to lazygit; delta and difftastic add their diff settings to git (delta
also adds lazygit's diff renderer); starship ships a small file that tweaks
its prompt in fish. That wiring belongs to the tool that provides the
behaviour, so it is present exactly when that tool is enabled, and
importing one tool never brings another with it:

```nix
imports = [ tools.git ];              # git keeps its own default pager
```

Add hunk and git also pages through it:

```nix
imports = [ tools.git tools.hunk ];   # git now also pages through `hunk pager`
```

To take one back out of a group, say so:

```nix
imports = [ git-tools ];              # includes hunk
tools.hunk.enable = false;            # git keeps its default pager, and
                                      # lazygit loses the two `hunk show` keys
```

Every tool takes `tools.<name>.enable`, so this works for anything a group
brought in.

## Groups

Each group is only a bundle of tool modules — there is nothing in a group
that is not in one of its tools.

| Group | Tools |
| --- | --- |
| `agent-tools` | `herdr`, `ccstatusline`, `beads`, `fabric`, `pet` |
| `editor` | `nvim`, `vim` |
| `git-tools` | `git`, `delta`, `difftastic`, `lazygit`, `gpg`, `tig`, `hunk` |
| `mcp` | `agentgateway`, `context7-mcp`, `serena-mcp`, `mcp-nixos`, `local-mcp` |
| `shell` | `fish`, `zsh`, `starship`, `direnv` |
| `ssh` | `ssh` |
| `terminal` | `alacritty`, `ghostty`, `tmux`, `tmuxp` |

How to consume and override these from your own configuration —
including a cookbook — is in **[docs/consuming.md](docs/consuming.md)**.

Per-tool detail — what each one writes, what it installs, and what it adds
to other tools — is in **[docs/tools.md](docs/tools.md)**.

All 28 tools: `agentgateway`, `alacritty`, `beads`, `ccstatusline`, `context7-mcp`, `delta`, `difftastic`, `direnv`, `fabric`, `fish`, `ghostty`, `git`, `gpg`, `herdr`, `hunk`, `lazygit`, `local-mcp`, `mcp-nixos`, `nvim`, `pet`, `serena-mcp`, `ssh`, `starship`, `tig`, `tmux`, `tmuxp`, `vim`, `zsh`.

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
