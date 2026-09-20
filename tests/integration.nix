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

  # difftastic: owns the difftool and the two aliases.
  "git alone has no difftastic lines" =
    !(git.programs.git.settings.alias ? dft) && !(git.programs.git.settings.diff ? tool);
  "git with difftastic sets the difftool" =
    (gitDifft.programs.git.settings.diff.tool or null)
    == "difftastic"
    && (gitDifft.programs.git.settings.alias.dft or null) == "difftool"
    && (gitDifft.programs.git.settings.difftool.difftastic.cmd or null) == ''difft "$LOCAL" "$REMOTE"'';
  "difftastic installs its package" = installs gitDifft "difftastic";

  # starship: ships its own fish tweak; fish does not import it.
  "fish alone does not bring starship" =
    !(fish.programs.starship.enable) && !(fish.home.file ? ".config/fish/conf.d/starship.fish");
  "fish with starship gets the tweak" =
    fishStarship.programs.starship.enable && fishStarship.home.file ? ".config/fish/conf.d/starship.fish";
  "the old numbered file is gone" = !(fishStarship.home.file ? ".config/fish/conf.d/40-starship.fish");
}
