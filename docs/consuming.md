# Consuming these modules

Three shapes of consumer, then a cookbook of overrides. Every snippet in
the cookbook is checked by evaluating it — see [Verified](#verified).

## 1. Someone else's config

Take what you want, nothing else.

```nix
{
  inputs.jskswamy.url = "github:jskswamy/nix-modules";

  # in a home-manager configuration
  imports = with inputs.jskswamy.homeManagerModules; [
    tools.fish
    tools.nvim
    tools.tmux
  ];
}
```

That installs fish, neovim and tmux and writes their config. Importing a
module is what asks for it; there is no `enable = true` to remember.

You do not have to apply `overlays.default`. A tool whose package is not in
nixpkgs (`hunk`, `beads`, `herdr`, `ccstatusline`) builds it from this repo
either way. Applying the overlay is only useful if you also want those
packages under `pkgs.*` for your own use.

## 2. A disposable box (cloudlab)

An ephemeral VM wants the same shell and editor as the daily driver, and
nothing tied to a particular person. That is the default behaviour: leave
`nixModules.sourceRoot` unset and every config file is read from the
flake's own immutable store path, so no checkout is needed.

```nix
# cloud-box.nix — import this from any host
{
  imports = with inputs.jskswamy.homeManagerModules; [
    tools.fish
    tools.starship
    tools.nvim
    tools.tmux
    tools.git
    tools.lazygit
  ];

  # git ships no identity, so supply one
  programs.git.settings.user = {
    name = "Alice Example";
    email = "alice@example.com";
  };
}
```

A custom group is exactly this file: write it once, import it from as many
hosts as you like. It can cut across the named groups however you want.

## 3. A daily driver with private overrides (nixos-config)

The pattern the split was built for: the public modules supply the generic
configuration, and a private layer on top supplies identity, client
context, and machine-specific paths.

```nix
imports = [
  jskswamy.homeManagerModules.common
  jskswamy.homeManagerModules.theme
  jskswamy.homeManagerModules.shell
  jskswamy.homeManagerModules.terminal
  jskswamy.homeManagerModules.editor
  jskswamy.homeManagerModules.ssh
  jskswamy.homeManagerModules.agent-tools
  jskswamy.homeManagerModules.git-tools

  ../private/git-identity.nix     # name, email, signing key, url.insteadOf
  ../private/repo-inventory.nix   # which orgs and repos this machine works with
  ../private/ssh-hosts.nix        # personal infrastructure
  ../private/herdr-projects.nix   # project definitions with absolute paths
  ../private/machine-paths.nix    # config pinning /Users/<user>/...
];

# Edit a dotfile in the checkout and it takes effect immediately, no rebuild.
nixModules.sourceRoot = "/Users/subramk/nix-modules";
theme.variant = "gruvbox";
```

A private override is an ordinary home-manager module. It sets only the
values it is overriding — never a copy of the generic config:

```nix
# private/git-identity.nix
{config, ...}: {
  programs.git = {
    signing.key = "${config.home.homeDirectory}/.ssh/id_ed25519_signing.pub";
    settings.user = {
      name = "Krishnaswamy Subramanian";
      email = "someone@example.com";
    };
  };
}
```

## Cookbook

### Swap the package a tool installs

```nix
imports = [ tools.nvim ];
tools.nvim.package = pkgs.neovim-nightly;
```

### Keep the config, install nothing

For a binary that comes from the system, Homebrew, or a language package
manager:

```nix
imports = [ tools.tig ];
tools.tig.package = null;      # ~/.config/tig/config still written
```

### Change a setting the module chose

Everything a consumer might reasonably override is `lib.mkDefault`, so an
ordinary assignment wins:

```nix
imports = [ tools.alacritty ];
programs.alacritty.settings.window.opacity = 0.8;
```

### Replace a whole file the module ships

These are set without `mkDefault`, so use `mkForce`:

```nix
imports = [ tools.tig ];
home.file.".config/tig/config".text = lib.mkForce "# my own tig config";
```

### Drop a tool that arrived as a dependency

```nix
imports = [ tools.lazygit ];   # brings hunk
tools.hunk.enable = false;     # ...and the two `hunk show` keys go with it
```

### Switch themes everywhere at once

```nix
theme.variant = "catppuccin";  # alacritty, ghostty, and any other
                               # themeable tool follow
```

### Edit dotfiles without rebuilding

```nix
nixModules.sourceRoot = "/Users/you/nix-modules";
```

Config files become out-of-store symlinks into that checkout, so editing
one takes effect immediately. Leave it unset and they come from the store
instead, which is what a disposable box wants.

## Verified

Each cookbook entry is evaluated against a bare home-manager configuration
and the result asserted, so the snippets cannot drift from the modules:

| Claim | Checked |
| --- | --- |
| importing a tool installs it | `tools.nvim` puts neovim in `home.packages` |
| `package` swaps it | `tools.tig.package = pkgs.hello` installs hello, not tig |
| `package = null` keeps config | `~/.config/tig/config` written, nothing installed |
| settings are overridable | `window.opacity` ends up `0.8` |
| files are replaceable | `mkForce` text wins |
| `theme.variant` propagates | alacritty imports `catppuccin_dark.toml` |
| overlay is optional | `tools.hunk` installs hunk with no overlay applied |
