# Moving tool integrations to the guest side: migration design

Status: draft for review
Date: 2026-09-20
Implements: ADR 0001, "A tool's integrations live with that tool"

## Goal

Make every tool module own its integrations, so that enabling a tool gives
you everything it adds to other tools and disabling it removes all of it.

The rule, restated so this document stands alone: a module is a package,
the config the tool itself reads, and its integrations, meaning
configuration that lives in another tool's files only because this tool is
installed. The tool that provides the behaviour (the guest) pushes its
integration into the tool that hosts it. A host never imports its guests,
and a guest never sets another nix-modules tool's options, because those
options exist only when that module is imported. Guests write to
home-manager's `programs.*` and `home.*`, which always exist and are inert
when the host is off, or drop a uniquely named file into a directory the
host reads.

## Why now

The fish module assumed tools that no module installs. On a fresh instance
every interactive start printed "Unknown command", and `diff` failed with
exit 127 because an alias replaced a working command with a missing one.
Auditing all tool modules found the same fault, and several relatives of
it, elsewhere.

## Non-goals

- Changing what any tool does on the daily-driver machine. Every phase must
  leave the evaluated result for the full tool set unchanged, apart from
  who owns each line.
- Modules for workflow-specific tools (`gita`, `git-workspace`, `sesh`,
  `glow`, `yt-dlp`, `kubectl`, `google-cloud-sdk`, `colima`). They follow
  the same pattern later.
- A helper for module boilerplate. See the defaults below.

## Findings

Locations are within `modules/tools`.

A. A host imports a guest (three cases):

- `fish` imports `starship`, and carries starship's prompt tweak.
- `git` imports `hunk`, and sets `pager = "hunk pager"` when it is on.
- `lazygit` imports `hunk`, and carries hunk's two keybindings.

B. A host configures a guest that it neither imports nor installs. This is
the same fault as fish on a bare instance:

- `git/git.nix` sets `interactive.diffFilter` and a `[delta]` section, and
  defines `dft`, `dftlog` and a difftastic difftool. Nothing installs
  `delta` or `difft`.
- `lazygit` configures a `delta` diff renderer. Nothing installs `delta`.
- `tig` binds keys that pipe into `delta` (13 references).
- `fish` aliases and configures `eza`, `bat`, `difft`, `fzf`, `jump` and
  `any-nix-shell`, none of which has a module.
- `zsh` sets `alias diff=difft`.

C. The same integration is written once per shell, and the copies disagree:

- The `claude-work` and `claude-personal` aliases appear in both `fish` and
  `zsh`.
- `EDITOR` is `nvim` in fish and `vim` in zsh.

D. A shell is hardcoded. This is wrong whenever the login shell chosen at
instance creation is zsh or bash:

- `ghostty/config/config` sets `shell-integration = "fish"`.
- `nvim/config/lua/config/options.lua` sets `vim.o.shell = "fish"`.

E. Claude Code is a host with no module. Five things each edit its
configuration in a different way:

- `direnv` carries a `use_claude_profile` function.
- `fish` and `zsh` carry the profile aliases.
- `ccstatusline` merges `statusLine` into `~/.claude/settings.json` with
  `jq`.
- `agentgateway` and `local-mcp` register MCP servers by calling
  `claude mcp add` in an activation script.

F. File-based hosts with no include mechanism hold guest lines:

- `tig/config/config` binds `delta`.
- `herdr/config/config.toml` holds three hunk keybindings (around lines
  405 to 417).

Modules with no findings: `agentgateway`'s own config, `alacritty`,
`beads`, `context7-mcp`, `fabric`, `mcp-nixos`, `serena-mcp`, `ssh`,
`tmux`, `tmuxp`, `vim`, `starship` (its `direnv` entry is starship's own
built-in module) and `pet` (its snippets are data that assume tools).

## Phases

Each phase is independently committable and leaves the evaluated result for
the full tool set unchanged. They are in dependency order.

### Phase 0: the repo defines its own hooks

Give the flake a `devShells.default` using git-hooks.nix, carrying the
hook list the maintainers already use, so contributors get the same tools
and hooks from `nix develop`, and exclusions live in the repo.

Decide how `docs/tools.md` meets the markdown rules. It currently fails
with 54 inline-HTML errors (the `<a id>` anchors and `<br>` in tables), 22
line-length errors and one fenced block with no language, and prettier
would rewrite 56 of its lines. Two options: exclude that generated file
from markdownlint and prettier, or change how it is produced. `README.md`
and `docs/consuming.md` have a few errors each that will surface when they
are next edited.

Consider a `dev/` sub-flake if adding an input to the public flake is
unwelcome, since consumers' lock files would otherwise list it.

Verification: a fresh clone runs `nix develop` and then a commit runs every
hook without error.

### Phase 1: modules for the tools the config already assumes

Add `delta` and `difftastic` first, because phase 2 depends on them, then
`eza`, `bat`, `fd`, `ripgrep`, `fzf`, `jump`, `zoxide` and `any-nix-shell`.
Each has `enable` and a `package` option (null means config only), like the
existing `tmuxp`.

Home-manager already has modules for `eza`, `bat`, `fzf`, `zoxide`,
`delta` and `difftastic`, so those wrap them, as `starship` wraps
`programs.starship`. Each decides whether to accept home-manager's
integration or switch it off and ship the exact current lines:

- `programs.eza` adds `ll`, `la` and `lt`; the current config only aliases
  `ls`, so its shell integration is off and the alias is set explicitly.
- `programs.difftastic` rewrites `git diff`; the current config only adds a
  difftool and a log alias, so the integration is off.

`jump`, `fd`, `ripgrep` and `any-nix-shell` are package-only unless a module
needs a snippet. `fzf` brings `fd`, because `FZF_ALT_C_COMMAND` uses it.

Also add a `cli-tools` group bundling them. The `default` set picks them up
without wiring changes.

Verification: each module evaluates alone, and adds its package only when
enabled and its `package` is not null.

### Phase 2: invert the imports

- `hunk` sets git's pager and adds its two keybindings to lazygit's custom
  commands. `git` and `lazygit` stop importing it.
- `delta` owns the `interactive.diffFilter` line and the `[delta]` section
  now in `git/git.nix`, and lazygit's diff renderer.
- `difftastic` owns `dft`, `dftlog` and the difftool.
- `starship` ships the fish prompt tweak, and `fish` stops importing it.

The tig and herdr lines stay, as the exception below.

Verification: for each host and guest, evaluate with the guest on and off.
The host's output contains the guest's lines exactly when the guest is on.
For the full set, the merged result equals the pre-phase result.

### Phase 3: aliases and environment through home-manager

Move aliases to `home.shellAliases` and environment variables to
`home.sessionVariables`, set by the tool that owns them:

- `eza`, `bat`, `difftastic` set their aliases; `bat` also sets `MANPAGER`
  and `BAT_THEME`.
- `nvim` sets `EDITOR` and `VISUAL`, and the `vim` and `vi` aliases.
- `lazygit` sets `lg`; `tmux` sets its `tmux` alias.
- `claude-work` and `claude-personal` go to whichever module comes to own
  Claude (phase 5).

Then delete the same lines from `fish` and `zsh`. These variables and
aliases now reach fish, zsh and bash alike.

Verification: with each of the three shells enabled, the alias and variable
sets are equal across shells and equal to the union of the old fish and zsh
sets, except for `EDITOR` (below).

### Phase 4: fish-specific snippets as drop-ins

Snippets that are not an alias or a variable move to a `fish/` directory in
the owning module, linked to `~/.config/fish/conf.d/<tool>.fish` through the
existing `mkSource`, keeping edit-without-rebuild. The directory is separate
from the tool's own `config/` because `nvim` and `tmuxp` link that
directory wholesale, and a snippet placed there would leak into it.

- `jump` and `any-nix-shell` startup lines.
- `fzf` variables.
- `gpg`: `GPG_TTY`, `GNUPGHOME`, the `SSH_AUTH_SOCK` lookup and the agent
  tty update.
- `direnv`: the `mkenvrc` function.
- `tmuxp`: the `hackspace` function.

Snippets run twice in an interactive session, because fish loads `conf.d`
itself and the fish module's init also loops over it. Each must be safe to
run twice.

What stays in fish: PATH, locale, colours, keybindings, its own functions,
and functions that need tools that have no module yet.

Verification: sourcing every fish file in an environment with none of the
tools present prints nothing and sets nothing tool-specific; with the
modules on, the sets of aliases, variables and functions match the
pre-phase result.

### Phase 5: Claude as a host

Home-manager already has `programs.claude-code`, with `settings`,
`mcpServers`, `hooks`, `agents`, `skills` and more, and
`enableMcpIntegration`. A `tools.claude` module would wrap it, and
`ccstatusline`, `agentgateway`, `local-mcp` and `direnv` would push into it
instead of each editing Claude's files their own way.

One property decides the design and is unresolved: home-manager writes
`settings.json` as a read-only symlink into the Nix store, and delivers MCP
servers through a generated plugin, not `claude mcp add`. Claude cannot
save its own changes, such as approved permissions or the model, to a
read-only file. Two ways forward, to settle in this phase's own design
before any code:

- Accept the declarative, read-only model, and require runtime changes to go
  to the local settings scope.
- Keep merging into the live file at activation time, as `ccstatusline`
  does today, and use the home-manager options only as the place guests
  declare what to merge.

This phase is independent of 3 and 4 and can run in parallel.

### Phase 6: remove the shell hardcodes

- `ghostty`: `shell-integration = "detect"`, which lets ghostty follow the
  shell in use.
- `nvim`: follow `$SHELL` instead of forcing fish.

Verify first that the daily-driver machine's `$SHELL` is fish, so nvim
terminals there do not change. That has not been checked.

### Phase 7: document and close out

- Add one exception to ADR 0001: where a host's config format has no include
  or merge mechanism, guest lines may sit inside it, commented as such. The
  list is closed: `tig` for `delta`, and `herdr` for `hunk`.
- Rewrite any contributor guidance that says a tool that configures another
  should import it and guard the coupled part.
- Update `docs/tools.md`, including how it describes what a tool brings
  with it.

## Defaults chosen

- **File-based hosts:** a closed exception, as in phase 7, not a rewrite of
  those tools' config formats.
- **`EDITOR` when both editors are enabled:** `nvim` sets it at normal
  priority and `vim` at a lower one, so `nvim` wins. A consumer can override
  either. This also fixes today's fish and zsh disagreement.
- **No helper for boilerplate yet.** Most new modules wrap a home-manager
  module and are short. Add a helper only if the package-only ones repeat
  enough to justify it.

## Open questions

- Phase 5's settings model, above.
- Whether `$SHELL` is fish on the daily-driver machine (phase 6).
- Whether two guests setting the same single-valued option, for example git's
  pager, fail at evaluation as expected. Standard module-system behaviour,
  untested against this repo's option types.
- Whether a guest adding entries to lazygit's custom commands concatenates
  with the list `tools.lazygit` already sets. The option is a freeform YAML
  type.
- Whether home-manager has `fd`, `ripgrep`, `jump` and `any-nix-shell`
  modules. Only `eza`, `bat`, `fzf`, `zoxide`, `delta` and `difftastic` were
  confirmed.

## Testing approach

Before phase 1, snapshot the evaluated configuration for the full tool set:
files written, git's settings, and every shell's aliases, variables and init
text. After each phase, diff against the snapshot; the only differences
allowed are the ones the phase intends.

For guests and hosts, evaluate both with the guest enabled and disabled and
assert the host's output changes with it. For fish, source every file in an
environment where none of the tools exist and assert clean output.
