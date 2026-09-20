# ADR 0001: A tool's integrations live with that tool

- Status: Proposed
- Date: 2026-09-20

## Context

### What a module is

A module under `modules/tools/<name>` is one tool's capability. It has three
parts:

1. **Package.** The binary. Optional: `tools.<name>.package = null` keeps the
   configuration and installs nothing, for a binary that comes from the
   system.
2. **Own config.** The files the tool itself reads, such as `starship.toml`
   or `tmux.conf`.
3. **Integrations.** Configuration that lives in _another_ tool's files and
   exists only because this tool is installed. Examples: the `ls` alias in the
   shell that points at `eza`, `core.pager` in git that points at `delta`,
   lazygit's keybinding that runs `hunk`.

Parts 1 and 2 have never been a problem. Part 3 has no rule, and the code
has drifted into putting it in the wrong place.

### The problem

Integrations were written into the _host_, which then had to know its guests.

- The fish module owned `10-aliases.fish`, which aliased `ls`, `cat` and
  `diff` to `eza`, `bat` and `difft`, and `99-interactive.fish`, which ran
  `jump` and `any-nix-shell`. None of those tools has a module. They were
  installed on the daily-driver machine only because its package list
  contained them.
- On a machine that lacks them, a fresh cloud instance, every interactive
  start printed "Unknown command", and `diff` failed with exit 127 because
  the alias replaced a working command with one that did not exist.
- `lazygit` imports `hunk` and carries hunk's keybindings. `fish` imports
  `starship` and carries starship's prompt tweak. `lazygit` pipes every diff
  through `delta`, which no module installs.

The guards added to fix the first case (`command -q eza; and alias ...`) treat
the symptom. The cause is that the host owns knowledge that belongs to the
guest.

A second constraint sharpens it. The login shell of an instance is chosen at
creation and may be fish, zsh or bash. An integration written as a fish-only
file silently disappears when zsh is chosen.

### What the module system already provides

Nix's answer is that the module system merges definitions from every module.
A host exposes options whose types merge (lists, attribute sets, lines of
text) and a guest writes into them. The guest never edits the host's file and
the host never names its guests. Home-manager, at the revision this repo
locks, already works this way:

- **`delta` to git:** writes git's config, guarded by
  `enableGitIntegration && programs.git.enable`.
- **`difftastic` to git:** sets `diff.external` and/or a difftool, with the
  same kind of guard.
- **`zoxide` to each shell:** writes `programs.fish.interactiveShellInit`,
  `programs.bash.initExtra` and `programs.zsh.initContent`, each behind
  `enable<Shell>Integration`, all defaulted from
  `home.shell.enableShellIntegration`.
- **Any tool to every shell:** `home.shellAliases` fans out to bash, zsh, fish
  and nushell; `home.sessionVariables` and `home.sessionPath` likewise.

Fish's own merge points are `shellAliases`, `shellAbbrs`, `shellInit`,
`loginShellInit`, `interactiveShellInit`, `functions` and `plugins`.

## Decision

**A tool's integrations live with that tool (the guest) and are pushed into
the host's extension point. A host never imports its guests. A host imports a
guest only for a hard requirement.**

The mechanism depends on what is being integrated:

- **Alias, environment variable, PATH entry:** `home.shellAliases`,
  `home.sessionVariables` and `home.sessionPath`, so every shell gets it.
- **Shell-specific init or a function, where live editing matters:** a
  drop-in file `conf.d/<tool>.fish` shipped from the tool's own `fish/`
  directory. The directory is the merge point: each tool adds a uniquely
  named file.
- **Git, lazygit, direnv and similar settings:** the host's mergeable option,
  such as `programs.git.settings`, `programs.lazygit.settings` or
  `programs.direnv.stdlib`.
- **A genuine hard requirement (the host cannot work without the guest):** the
  host imports the guest and guards with `config.tools.<guest>.enable`, as
  today.

Supporting rules:

1. **A guest never sets another nix-modules tool's options.** Those options
   exist only if that module is imported, so writing them drags the host in.
   A guest writes to home-manager's `programs.*` and `home.*`, which always
   exist and are inert when the host is disabled, or to a drop-in file.
2. **Where a home-manager module already covers the tool** (`programs.eza`,
   `bat`, `zoxide`, `fzf`, `delta`, `difftastic`), the nix-modules module
   wraps it, as `tools.starship` wraps `programs.starship`. A module then
   chooses per tool between accepting home-manager's integration and turning
   it off to ship its own. Example: `programs.eza` adds `ll`, `la` and `lt`,
   and `programs.difftastic` rewrites `git diff`; where those are unwanted the
   module disables the integration and sets the exact aliases itself.
3. **Live editing.** Aliases and variables go through the home-manager
   primitives and are therefore generated config, editable only by
   rebuilding. Multi-line, shell-specific snippets stay as files under the
   tool's own `fish/` directory and keep the `nixModules.sourceRoot`
   edit-without-rebuild behaviour. The snippet directory is separate from the
   tool's own `config/` because some tools link that directory wholesale
   (`nvim`, `tmuxp`), and a snippet placed there would leak into the tool's
   own config directory.
4. **Single-valued settings conflict.** If two guests set the same
   single-valued option (for instance two tools setting `core.pager`),
   evaluation is expected to fail rather than silently pick one. The
   consumer resolves it, by disabling one or with a priority.

## Consequences

Good:

- Enabling a tool gives you its integrations; disabling it removes them. No
  guards of the form `command -q eza` are needed for anything a module owns.
- The shell can be fish, zsh or bash and aliases and variables still apply.
- Hosts shrink to what only they know. `tools.fish` keeps shell-level config:
  PATH, colours, keybindings, its own functions.
- Adding a tool touches one directory.

Costs and follow-ups:

- The convention in use today, written into consumers' contributor guidance
  as "a tool that configures another imports it and guards the coupled
  part", is the opposite of this rule. This ADR supersedes it, and any
  such guidance must be rewritten to match.
- `lazygit` should stop importing `hunk`; `hunk` adds its keybindings to
  `programs.lazygit.settings` (a list, so definitions concatenate).
  `fish` should stop importing `starship`; starship ships its own fish
  tweak. Both are behaviour-preserving moves.
- Tools the fish config depends on but that have no module (`eza`, `bat`,
  `difftastic`, `fd`, `ripgrep`, `fzf`, `jump`, `zoxide`, `any-nix-shell`,
  `delta`) each get one. Workflow-specific tools (`gita`, `git-workspace`,
  `sesh`, `glow`, `yt-dlp`, `kubectl`, `google-cloud-sdk`, `colima`) are
  deferred and follow the same pattern when added.
- Snippets that belong to existing modules (`lazygit`, `nvim`, `tmux`,
  `tmuxp`, `gpg`, `direnv`) move out of fish's files into those modules.
- The "brings with it" column in `docs/tools.md`, generated from imports,
  will list fewer entries as imports become guest-side writes.
- `docs/tools.md` needs a way to show what a tool integrates into.

## Not verified

- That two guests setting the same single-valued option fail at evaluation
  (rule 4). This is standard module-system behaviour but has not been tested
  against this repo's option types.
- That `hunk` adding entries to `programs.lazygit.settings.customCommands`
  from its own module concatenates with the list `tools.lazygit` already
  sets. Lists merge by concatenation in the module system, but the option
  is a freeform YAML type and this has not been evaluated here.
- That a package's `share/fish/vendor_conf.d/` is discovered by a
  home-manager-managed fish. If it is, a package could carry its own
  integration with no wiring at all, but it would lose live editing, so it is
  not part of this decision.

## Alternatives considered

- **Keep the host owning integrations, guarded with `command -q`.** Works
  today but the host must list every guest, and the guards do not follow a
  tool being disabled by configuration, only by absence of the binary.
- **A registry option on the host** such as `tools.fish.snippets.<name>`.
  Every guest would depend on the fish module existing, which is the coupling
  this decision removes.
- **Wrap the binary** (`makeWrapper`) to bake in environment or arguments.
  Suits values that belong to the process, not aliases or shell init.
- **Use home-manager's `programs.*` directly in the consumer** and drop the
  wrapper layer. Loses the shared defaults and the per-tool package option
  that consumers of this repo rely on.
