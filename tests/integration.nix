# Asserts that a host's output contains a guest's lines exactly when the
# guest is enabled. Every attribute is a boolean; check.sh fails on any false.
# Needs --impure, for getFlake on the working tree.
let
  hm = builtins.getFlake "github:nix-community/home-manager/4ac5a2ae9025eab1ebece4f9df8c315fd84a738a";
  nm = builtins.getFlake "path:${toString ../.}";
  pkgs = import nm.inputs.nixpkgs {system = builtins.currentSystem;};
  inherit (pkgs) lib;

  mk = modules:
    (hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules =
        [
          {
            home.username = "t";
            home.homeDirectory = "/home/t";
            home.stateVersion = "24.05";
          }
        ]
        ++ modules;
    }).config;

  T = nm.homeManagerModules.tools;
  installs = c: prefix: builtins.any (p: lib.hasPrefix prefix (p.name or "")) c.home.packages;
  commands = c: map (x: x.description) (c.programs.lazygit.settings.customCommands or []);

  git = mk [T.git];
  gitHunk = mk [T.git T.hunk];
  gitDelta = mk [T.git T.delta];
  gitDifft = mk [T.git T.difftastic];
  lazygit = mk [T.lazygit];
  lazygitHunk = mk [T.lazygit T.hunk];
  lazygitDelta = mk [T.lazygit T.delta];
  hunkOnly = mk [T.hunk];
  fish = mk [T.fish];
  fishStarship = mk [T.fish T.starship];

  eza = mk [T.eza];
  bat = mk [T.bat];
  fd = mk [T.fd];
  ripgrep = mk [T.ripgrep];
  fzf = mk [T.fzf];
  zoxide = mk [T.zoxide];
  jump = mk [T.jump];
  anyNixShell = mk [T."any-nix-shell"];
  cliTools = mk [nm.homeManagerModules.cli-tools];
  gitTools = mk [nm.homeManagerModules.git-tools];
  gitLfs = mk [T."git-lfs"];
  gitLfsTransfer = mk [T."git-lfs-transfer"];
  nvim = mk [T.nvim];
  vim = mk [T.vim];
  tmux = mk [T.tmux];
  nvimVim = mk [T.nvim T.vim];
  aliasParity = mk [
    T.fish
    T.zsh
    T.eza
    T.bat
    T.difftastic
    T.nvim
    T.lazygit
    T.tmux
    {programs.bash.enable = true;}
  ];
  zshSource = builtins.readFile ../modules/tools/zsh/default.nix;
in {
  # hunk: the guest pushes into git and lazygit; neither imports it.
  "git alone does not bring hunk" = !(installs git "hunk");
  "git alone keeps the default pager" = !(git.programs.git.settings.core ? pager);
  "git with hunk sets the pager" = (gitHunk.programs.git.settings.core.pager or null) == "hunk pager";
  "lazygit alone does not bring hunk" = !(installs lazygit "hunk");
  "lazygit alone has only its own command" = commands lazygit == ["AI commit with Claude"];
  "lazygit with hunk gains both hunk commands" =
    lib.sort (a: b: a < b) (commands lazygitHunk)
    == ["AI commit with Claude" "Review branch tip with hunk" "Review commit with hunk"];
  "hunk alone does not enable git" = !hunkOnly.programs.git.enable;
  # Positive control: git's config is keyed by its absolute path, so a lookup by
  # the relative path would never match and any "writes no config" test would
  # pass whatever hunk did.
  "git alone enables git and writes its config" =
    git.programs.git.enable && git.home.file ? "/home/t/.config/git/config";

  # delta: owns the diff filter, its own settings, and lazygit's renderer.
  "git alone has no delta lines" = !(git.programs.git.settings ? delta) && !(git.programs.git.settings ? interactive);
  "git with delta sets the filter" = (gitDelta.programs.git.settings.interactive.diffFilter or null) == "delta --color-only";
  "git with delta keeps its settings" = (gitDelta.programs.git.settings.delta.line-numbers or null) == true;
  "delta installs its package" = installs gitDelta "delta";
  "lazygit alone has no diff renderer" = !(lazygit.programs.lazygit.settings ? git && lazygit.programs.lazygit.settings.git ? diffRenderers);
  "lazygit with delta gains the renderer" =
    (builtins.head (lazygitDelta.programs.lazygit.settings.git.diffRenderers or [{}])).command or null == "delta --paging=never";
  "lazygit sets the lg alias" = lazygit.home.shellAliases.lg == "lazygit";
  "tmux sets its alias" = tmux.home.shellAliases.tmux == "tmux new-session -A";

  # difftastic: owns the difftool and the two aliases.
  "git alone has no difftastic lines" =
    !(git.programs.git.settings.alias ? dft) && !(git.programs.git.settings.diff ? tool);
  "git with difftastic sets the difftool" =
    (gitDifft.programs.git.settings.diff.tool or null)
    == "difftastic"
    && (gitDifft.programs.git.settings.alias.dft or null) == "difftool"
    && (gitDifft.programs.git.settings.difftool.difftastic.cmd or null) == ''difft "$LOCAL" "$REMOTE"'';
  "difftastic installs its package" = installs gitDifft "difftastic";
  "difftastic sets the diff alias" = (mk [T.difftastic]).home.shellAliases.diff == "difft";

  # starship: ships its own fish tweak; fish does not import it.
  "fish alone does not bring starship" =
    !(fish.programs.starship.enable) && !(fish.home.file ? ".config/fish/conf.d/starship.fish");
  "fish with starship gets the tweak" =
    fishStarship.programs.starship.enable && fishStarship.home.file ? ".config/fish/conf.d/starship.fish";
  "the old numbered file is gone" = !(fishStarship.home.file ? ".config/fish/conf.d/40-starship.fish");

  # editors: nvim wins when both editor modules are enabled.
  "nvim sets EDITOR" = nvim.home.sessionVariables.EDITOR == "nvim";
  "vim alone sets EDITOR to vim" = vim.home.sessionVariables.EDITOR == "vim";
  "nvim wins over vim" = nvimVim.home.sessionVariables.EDITOR == "nvim";
  "nvim sets the vim and vi aliases" = nvim.home.shellAliases.vim == "nvim" && nvim.home.shellAliases.vi == "nvim";
  "aliases are equal in fish, zsh and bash" =
    aliasParity.programs.fish.shellAliases
    == aliasParity.programs.zsh.shellAliases
    && aliasParity.programs.zsh.shellAliases == aliasParity.programs.bash.shellAliases
    && aliasParity.programs.fish.shellAliases.ls == "eza --icons=always";
  "zsh does not redefine ls or diff" =
    !(lib.hasInfix "alias diff=" zshSource)
    && !(lib.hasInfix "alias ls=" zshSource);

  # package-only CLI tools: install only their package for now; aliases and
  # shell snippets move in later issues.
  "eza installs its package" = installs eza "eza";
  "eza with package null installs nothing" = !(installs (mk [T.eza {tools.eza.package = null;}]) "eza");
  "eza sets the ls alias" = eza.home.shellAliases.ls == "eza --icons=always";
  "disabled eza sets no ls alias" = !((mk [T.eza {tools.eza.enable = false;}]).home.shellAliases ? ls);
  "bat installs its package" = installs bat "bat";
  "bat with package null installs nothing" = !(installs (mk [T.bat {tools.bat.package = null;}]) "bat");
  "bat sets cat, MANPAGER and BAT_THEME" =
    bat.home.shellAliases.cat
    == "bat"
    && bat.home.sessionVariables.MANPAGER == "bat -l man -p"
    && bat.home.sessionVariables.BAT_THEME == "ansi";
  "fd installs its package" = installs fd "fd";
  "fd with package null installs nothing" = !(installs (mk [T.fd {tools.fd.package = null;}]) "fd");
  "ripgrep installs its package" = installs ripgrep "ripgrep";
  "ripgrep with package null installs nothing" = !(installs (mk [T.ripgrep {tools.ripgrep.package = null;}]) "ripgrep");
  "fzf installs its package" = installs fzf "fzf";
  "fzf with package null installs nothing" = !(installs (mk [T.fzf {tools.fzf.package = null;}]) "fzf");
  "jump installs its package" = installs jump "jump";
  "jump with package null installs nothing" = !(installs (mk [T.jump {tools.jump.package = null;}]) "jump");
  "jump ships its fish snippet" = jump.home.file ? ".config/fish/conf.d/jump.fish";
  "disabled jump ships nothing" = !((mk [T.jump {tools.jump.enable = false;}]).home.file ? ".config/fish/conf.d/jump.fish");
  "any-nix-shell installs its package" = installs anyNixShell "any-nix-shell";
  "any-nix-shell with package null installs nothing" = !(installs (mk [T."any-nix-shell" {tools."any-nix-shell".package = null;}]) "any-nix-shell");
  "any-nix-shell ships its fish snippet" = anyNixShell.home.file ? ".config/fish/conf.d/any-nix-shell.fish";

  # zoxide intentionally wraps home-manager's module so it owns shell
  # integration later instead of being package-only.
  "zoxide enables programs.zoxide" = zoxide.programs.zoxide.enable;
  "zoxide off does not enable it" = !(mk [T.zoxide {tools.zoxide.enable = false;}]).programs.zoxide.enable;
  "zoxide installs its package" = installs zoxide "zoxide";

  "cli-tools installs all eight" = builtins.all (prefix: installs cliTools prefix) [
    "any-nix-shell"
    "bat"
    "eza"
    "fd"
    "fzf"
    "jump"
    "ripgrep"
    "zoxide"
  ];

  # Git LFS tools requested as git-tool modules.
  "git-lfs enables git lfs" = gitLfs.programs.git.lfs.enable;
  "git-lfs installs its package" = installs gitLfs "git-lfs";
  "git-lfs off does not enable it" = !(mk [T."git-lfs" {tools."git-lfs".enable = false;}]).programs.git.lfs.enable;
  "git-lfs-transfer installs its package" = installs gitLfsTransfer "git-lfs-transfer";
  "git-lfs-transfer with package null installs nothing" = !(installs (mk [T."git-lfs-transfer" {tools."git-lfs-transfer".package = null;}]) "git-lfs-transfer");
  "git-tools includes lfs tools" = gitTools.programs.git.lfs.enable && installs gitTools "git-lfs-transfer";
}
