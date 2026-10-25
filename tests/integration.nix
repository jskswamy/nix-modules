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
  workspaceRelative = mk [T.fish {nixModules.workspaceRoot = "src";}];
  workspaceTilde = mk [T.fish {nixModules.workspaceRoot = "~/code";}];
  workspaceHome = mk [T.fish {nixModules.workspaceRoot = "$HOME/projects";}];
  workspaceAbsolute = mk [T.fish {nixModules.workspaceRoot = "/Volumes/work/source";}];
  direnv = mk [T.direnv];

  eza = mk [T.eza];
  bat = mk [T.bat];
  fd = mk [T.fd];
  ripgrep = mk [T.ripgrep];
  fzf = mk [T.fzf];
  zoxide = mk [T.zoxide];
  jump = mk [T.jump];
  anyNixShell = mk [T."any-nix-shell"];
  bivouac = mk [T.bivouac {programs.bivouac.enable = true;}];
  bivouacText = bivouac.home.file.".config/bivouac/base.pkl".text;
  bivouacCustom = mk [
    T.bivouac
    {
      programs.bivouac = {
        enable = true;
        sshKeys = ["machine-key"];
        nixModules.workspaceRoot = "workspaces";
        extraSettings."custom.option" = "value";
      };
    }
  ];
  bivouacCustomText = bivouacCustom.home.file.".config/bivouac/base.pkl".text;
  agConfig = builtins.readFile ../modules/tools/agentgateway/config/config.yaml;
  agDefault = mk [T.agentgateway {tools.agentgateway.package = null;}];
  agNoReg = mk [
    T.agentgateway
    {
      tools.agentgateway = {
        package = null;
        registerMcp = false;
      };
    }
  ];
  cliTools = mk [nm.homeManagerModules.cli-tools];
  gitTools = mk [nm.homeManagerModules.git-tools];
  gitLfs = mk [T."git-lfs"];
  gitLfsTransfer = mk [T."git-lfs-transfer"];
  fresh = mk [T.fresh];
  freshConfig = builtins.fromJSON fresh.home.file.".config/fresh/config.json".text;
  freshDisabled = mk [T.fresh {tools.fresh.enable = false;}];
  editor = mk [nm.homeManagerModules.editor];
  nvim = mk [T.nvim];
  nvimDisabled = mk [T.nvim {tools.nvim.enable = false;}];
  nvimPackageNames = map lib.getName nvim.home.packages;
  vim = mk [T.vim];
  tmux = mk [T.tmux];
  tmuxp = mk [T.tmuxp];
  nvimVim = mk [T.nvim T.vim];
  gpg = mk [T.gpg];
  fishEnvSource = builtins.readFile ../modules/tools/fish/config/conf.d/00-environment.fish;
  fishFunctionsSource = builtins.readFile ../modules/tools/fish/config/conf.d/30-functions.fish;
  godirSource = builtins.readFile ../modules/tools/fish/config/functions/godir.fish;
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
  # Evaluates for another platform; nothing is built.
  mkOn = system: modules:
    (hm.lib.homeManagerConfiguration {
      pkgs = import nm.inputs.nixpkgs {inherit system;};
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
  skillshare = mk [T.skillshare];
  skillshareOff = mk [T.skillshare {tools.skillshare.enable = false;}];
  ss = skillshare.tools.skillshare;
  ssRes = ss.resources;
  # Plugin compatibility as `skillshare plugin discover` reported it.
  ssCompat = (lib.importJSON ../modules/tools/skillshare/fixtures/plugins.json).plugins;
  ssClaude = ["claude"];
  ssAll = ssClaude ++ ["pi"];
  # The --target values of an entry, sorted.
  ssTargets = e:
    lib.sort (a: b: a < b) (lib.concatLists (lib.imap0 (i: a:
      lib.optional (a == "--target") (builtins.elemAt e.args (i + 1)))
    e.args));
  ssEntry = kind: name: lib.findFirst (e: e.name == name) null ssRes.${kind};
  ssNames = kind: c: lib.sort (a: b: a < b) (map (e: e.name) c.tools.skillshare.resources.${kind});
  ssArgs = lib.concatMap (e: e.args) (ssRes.skills ++ ssRes.plugins ++ ssRes.mcp ++ ssRes.hooks);
  ssExcludes = t: lib.sort (a: b: a < b) (ssRes.excludes.${t} or []);
  ssBundled = name: ssCompat.${name}.skills or [];
  jskswamyBundles = ["bivouac" "codebase" "commit-tools" "craft" "devenv" "jot" "refactor" "sketch-note" "study" "typst-notes"];
  ssRtk = builtins.fromJSON (builtins.readFile (lib.last (ssEntry "hooks" "rtk").args));
  # What the activation hands to reconcile.sh.
  ssDecl = ss.declarations;
  ssNoGateway = mk [T.skillshare {tools.skillshare.enableAgentgateway = false;}];
  # A consumer adds an account profile and an MCP server for it alone.
  ssExtra = mk [
    T.skillshare
    {
      tools.skillshare = {
        profiles.claude-extra = {
          agent = "claude";
          configDir = "/home/t/.claude-extra";
        };
        mcpServers.extra = {
          profiles = ["claude-extra"];
          args = ["--url" "https://mcp.example.invalid/mcp"];
        };
      };
    }
  ];
  ssCli = mk [T.skillshare T.codex T.antigravity-cli];
  ssCliTargets = name: ssTargets (lib.findFirst (e: e.name == name) null ssCli.tools.skillshare.resources.plugins);
  ssExtraEntry = kind: name: lib.findFirst (e: e.name == name) null ssExtra.tools.skillshare.resources.${kind};
  ssExtraTarget = lib.findFirst (e: e.name == "claude-extra") null ssExtra.tools.skillshare.declarations.targets;
  # Failed assertion messages. Home Manager's own entry point throws on
  # any, so this evaluates its modules directly to read them.
  failedMessages = modules: let
    hmLib = import "${hm}/modules/lib/stdlib-extended.nix" lib;
    raw = hmLib.evalModules {
      class = "homeManager";
      specialArgs.modulesPath = "${hm}/modules";
      modules =
        [
          {
            home.username = "t";
            home.homeDirectory = "/home/t";
            home.stateVersion = "24.05";
          }
        ]
        ++ modules
        ++ import "${hm}/modules/modules.nix" {
          inherit pkgs;
          lib = hmLib;
        };
    };
  in
    map (a: a.message) (builtins.filter (a: !a.assertion) raw.config.assertions);
  ssBadMcp = failedMessages [
    T.skillshare
    {
      tools.skillshare.mcpServers.extra = {
        profiles = ["nope"];
        args = ["--url" "https://mcp.example.invalid/mcp"];
      };
    }
  ];
  ssNoTime = mk [T.skillshare {tools.skillshare.timeServerPackage = null;}];
  ssOwnTime = mk [
    T.skillshare
    {
      tools.skillshare = {
        timeServerPackage = null;
        mcpServers.time.args = ["--" "/opt/time/bin/mcp-server-time"];
      };
    }
  ];
  # Claude-only bundles beyond jskswamy/skills and Beads.
  ssClaudeOnly = ["context7" "gopls-lsp" "mattpocock-skills"];
  ssMatt = ssEntry "skills" "setup-matt-pocock-skills";
  agentTools = mk [nm.homeManagerModules.agent-tools];
in {
  # Agent CLIs install only their selected package, without owning login state.
  "agent CLI modules are exported" = T ? antigravity-cli && T ? codex && T ? opencode;
  "agent CLIs install their packages" = builtins.all (name: installs (mk [T.${name}]) name) ["antigravity-cli" "codex" "opencode"];
  "disabled agent CLIs install nothing" = builtins.all (name:
    map lib.getName (mk [T.${name} {tools.${name}.enable = false;}]).home.packages
    == map lib.getName (mk []).home.packages) ["antigravity-cli" "codex" "opencode"];
  "agent CLIs accept package null" = builtins.all (name:
    map lib.getName (mk [T.${name} {tools.${name}.package = null;}]).home.packages
    == map lib.getName (mk []).home.packages) ["antigravity-cli" "codex" "opencode"];
  "agent CLIs accept package overrides" = builtins.all (name:
    installs (mk [T.${name} {tools.${name}.package = pkgs.hello;}]) "hello"
    && !(installs (mk [T.${name} {tools.${name}.package = pkgs.hello;}]) name)) ["antigravity-cli" "codex" "opencode"];
  "agent-tools includes all agent CLIs" = installs agentTools "antigravity-cli" && installs agentTools "codex" && installs agentTools "opencode";

  # hunk: the guest pushes into git and lazygit; neither imports it.
  "git alone does not bring hunk" = !(installs git "hunk");
  "git alone keeps the default pager" = !(git.programs.git.settings.core ? pager);
  "git with hunk sets the pager" = (gitHunk.programs.git.settings.core.pager or null) == "hunk pager";
  "gpg ships its fish snippet" = gpg.home.file ? ".config/fish/conf.d/gpg.fish";
  "disabled gpg ships no fish snippet" = !((mk [T.gpg {tools.gpg.enable = false;}]).home.file ? ".config/fish/conf.d/gpg.fish");
  "the fish module no longer mentions gpg" =
    !(lib.hasInfix "GPG_TTY" fishEnvSource)
    && !(lib.hasInfix "gpgconf" fishEnvSource);
  "lazygit alone does not bring hunk" = !(installs lazygit "hunk");
  "lazygit alone has only its own command" = commands lazygit == ["AI commit with Claude"];
  "lazygit with hunk gains both hunk commands" =
    lib.sort (a: b: a < b) (commands lazygitHunk)
    == ["AI commit with Claude" "Review branch tip with hunk" "Review commit with hunk"];
  "skillshare package is pinned" = nm.packages.${builtins.currentSystem}.skillshare.version == "0.26.3";
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
  "tmuxp ships hackspace" = tmuxp.home.file ? ".config/fish/functions/hackspace.fish";
  "disabled tmuxp ships no hackspace" = !((mk [T.tmuxp {tools.tmuxp.enable = false;}]).home.file ? ".config/fish/functions/hackspace.fish");
  "fish conf.d no longer defines hackspace" = !(lib.hasInfix "function hackspace" fishFunctionsSource);
  "workspaceRoot defaults relative to home" = fish.home.sessionVariables.GIT_WORKSPACE == "/home/t/source";
  "workspaceRoot accepts relative paths" = workspaceRelative.home.sessionVariables.GIT_WORKSPACE == "/home/t/src";
  "workspaceRoot accepts tilde paths" = workspaceTilde.home.sessionVariables.GIT_WORKSPACE == "/home/t/code";
  "workspaceRoot accepts HOME paths" = workspaceHome.home.sessionVariables.GIT_WORKSPACE == "/home/t/projects";
  "workspaceRoot accepts absolute paths" = workspaceAbsolute.home.sessionVariables.GIT_WORKSPACE == "/Volumes/work/source";
  "fish environment does not set GIT_WORKSPACE" = !(lib.hasInfix "GIT_WORKSPACE" fishEnvSource);
  "godir uses configurable workspace" =
    lib.hasInfix "fd . $GIT_WORKSPACE" godirSource
    && lib.hasInfix ''set -gx GIT_WORKSPACE "$HOME/source"'' godirSource
    && !(lib.hasInfix "fd . $HOME/source" godirSource);

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
  "direnv ships mkenvrc" = direnv.home.file ? ".config/fish/functions/mkenvrc.fish";
  "disabled direnv ships no mkenvrc" = !((mk [T.direnv {tools.direnv.enable = false;}]).home.file ? ".config/fish/functions/mkenvrc.fish");
  "fish alone does not ship mkenvrc" = !(fish.home.file ? ".config/fish/functions/mkenvrc.fish");

  "fresh installs the editor" = installs fresh "fresh";
  "fresh inherits terminal colors" = freshConfig.theme == "terminal";
  "fresh starts in vi mode" = freshConfig.plugins.vi_mode.enabled && freshConfig.plugins.vi_mode.settings.autoStart;
  "fresh enables LSP" =
    freshConfig.lsp_enabled
    && builtins.all (language: freshConfig.lsp.${language}.enabled && freshConfig.lsp.${language}.auto_start) [
      "go"
      "python"
      "rust"
      "javascript"
      "typescript"
      "yaml"
      "toml"
      "markdown"
      "nix"
      "json"
      "jsonc"
      "bash"
      "html"
      "css"
    ];
  "fresh installs language servers" = builtins.all (name: installs fresh name) [
    "gopls"
    "pyright"
    "rust-analyzer"
    "typescript-language-server"
    "yaml-language-server"
    "taplo"
    "marksman"
    "nil"
    "vscode-langservers-extracted"
    "bash-language-server"
  ];
  "fresh uses pyright for Python" = freshConfig.lsp.python.command == "pyright-langserver" && freshConfig.lsp.python.args == ["--stdio"];
  "fresh settings are overridable" = (builtins.fromJSON (mk [T.fresh {tools.fresh.settings.theme = "gruvbox";}]).home.file.".config/fresh/config.json".text).theme == "gruvbox";
  "disabled fresh installs no editor or language servers" = map (p: p.name) freshDisabled.home.packages == map (p: p.name) (mk []).home.packages;
  "disabled fresh writes no config" = !(freshDisabled.home.file ? ".config/fresh/config.json");
  "editor group includes fresh and keeps nvim default" = installs editor "fresh" && editor.home.sessionVariables.EDITOR == "nvim";

  # editors: nvim wins when both editor modules are enabled.
  "nvim sets EDITOR" = nvim.home.sessionVariables.EDITOR == "nvim";
  "nvim sets VISUAL" = nvim.home.sessionVariables.VISUAL == "nvim";
  "nvim supplies a prebuilt LaTeX parser" = nvim.xdg.dataFile ? "nvim/site/parser/latex.so";
  "nvim records the prebuilt LaTeX revision" = (nvim.xdg.dataFile."nvim/site/parser-info/latex.revision".text or "") == pkgs.vimPlugins.nvim-treesitter.builtGrammars.latex.src.rev;
  "nvim supplies pinned LaTeX queries" = nvim.xdg.dataFile ? "nvim/site/queries/latex";
  "disabled nvim writes no LaTeX parser" = !(nvimDisabled.xdg.dataFile ? "nvim/site/parser/latex.so");
  "nvim supplies a platform compiler" = builtins.elem (lib.getName pkgs.stdenv.cc) nvimPackageNames;
  "nvim supplies parser and Mason runtimes" = builtins.all (name: builtins.elem name nvimPackageNames) [
    "tree-sitter"
    "git"
    "curl"
    "gnutar"
    "gzip"
    "unzip"
    "nodejs"
    "go"
    "ripgrep"
    "fd"
  ];
  "nvim supplies configured language commands" = builtins.all (name: builtins.elem name nvimPackageNames) [
    "nil"
    "alejandra"
    "statix"
    "deadnix"
    "pkl"
    "terraform"
  ];
  "nvim supplies Java for the Pkl language server" = builtins.elem (lib.getName pkgs.jre_headless) nvimPackageNames;
  "nvim supplies Python with pip" = builtins.elem (lib.getName (pkgs.python3.withPackages (ps: [ps.pip]))) nvimPackageNames;
  "nvim runtime packages are overridable" =
    !(installs (mk [T.nvim {tools.nvim.runtimePackages = lib.mkForce [];}]) "tree-sitter");
  "nvim with package null retains runtime support" = let
    c = mk [T.nvim {tools.nvim.package = null;}];
  in
    !(installs c "neovim") && installs c "tree-sitter";
  "nvim runtimes evaluate on Linux and Darwin" =
    builtins.all (system:
      builtins.deepSeq (map lib.getName (mkOn system [T.nvim]).tools.nvim.runtimePackages) true) ["x86_64-linux" "aarch64-darwin"];
  "disabled nvim adds no packages" = map lib.getName nvimDisabled.home.packages == map lib.getName (mk []).home.packages;
  "disabled nvim writes no config" = !(nvimDisabled.home.file ? ".config/nvim");
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
  "bivouac editor tab is a single Fresh pane" =
    bivouac.programs.bivouac.herdrTabs
    == [
      {
        label = "agent";
        panes = [
          {
            label = "agent";
            command = null;
          }
        ];
      }
      {
        label = "lazygit";
        panes = [
          {
            label = "lazygit";
            command = "lazygit";
          }
        ];
      }
      {
        label = "editor";
        panes = [
          {
            label = "editor";
            command = "fresh .";
          }
        ];
      }
    ];
  "bivouac installs Fresh remotely" = builtins.elem "tools.fresh" bivouac.programs.bivouac.nixModules.modules && lib.hasInfix "tools.fresh" bivouacText;
  "bivouac renders Fresh command" = lib.hasInfix ''command = "fresh ."'' bivouacText && !(lib.hasInfix ''label = "term"'' bivouacText);
  "bivouac writes base config" = bivouac.home.file ? ".config/bivouac/base.pkl";
  "bivouac defaults workspace root" = lib.hasInfix ''["nixModules.workspaceRoot"] = "sessions"'' bivouacText;
  "bivouac does not force git identity" =
    !(lib.hasInfix "programs.git.settings.user.name" bivouacText)
    && !(lib.hasInfix "programs.git.settings.user.email" bivouacText);
  "bivouac accepts machine overrides" =
    lib.hasInfix ''"machine-key"'' bivouacCustomText
    && lib.hasInfix ''["nixModules.workspaceRoot"] = "workspaces"'' bivouacCustomText
    && lib.hasInfix ''["custom.option"] = "value"'' bivouacCustomText;
  "bivouac imports skillshare, which brings codebase-memory" =
    lib.hasInfix ''"tools.skillshare"'' bivouacText;
  "bivouac takes skillshare defaults: claude and pi, no extra MCP" =
    !(lib.hasInfix "tools.skillshare.profiles" bivouacText)
    && !(lib.hasInfix "tools.skillshare.mcpServers" bivouacText)
    && !(lib.hasInfix "portableProfiles" bivouacText)
    && builtins.attrNames ss.profiles == ["claude" "pi"]
    && ssNames "mcp" ssNoGateway == ["chrome-devtools" "codebase-memory-mcp" "time"];
  "bivouac enables skillshare without AgentGateway" =
    lib.hasInfix ''["tools.skillshare.enable"] = true'' bivouacText
    && lib.hasInfix ''["tools.skillshare.enableAgentgateway"] = false'' bivouacText;
  "agentgateway config targets only things-cloud" =
    lib.hasInfix "name: things-cloud" agConfig
    && !(lib.any (n: lib.hasInfix "name: ${n}" agConfig) ["context7" "serena" "nixos"])
    && !(lib.hasInfix "1mcp" agConfig);
  "agentgateway registers Claude MCP by default" = agDefault.home.activation ? configureClaudeCodeAgentgateway;
  "agentgateway registration can be disabled" = !(agNoReg.home.activation ? configureClaudeCodeAgentgateway);
  "disabled bivouac writes no base config" = !((mk [T.bivouac]).home.file ? ".config/bivouac/base.pkl");
  "fd installs its package" = installs fd "fd";
  "fd with package null installs nothing" = !(installs (mk [T.fd {tools.fd.package = null;}]) "fd");
  "ripgrep installs its package" = installs ripgrep "ripgrep";
  "ripgrep with package null installs nothing" = !(installs (mk [T.ripgrep {tools.ripgrep.package = null;}]) "ripgrep");
  "fzf installs its package" = installs fzf "fzf";
  "fzf with package null installs nothing" = !(installs (mk [T.fzf {tools.fzf.package = null;}]) "fzf");
  "fzf brings fd" = installs fzf "fd";
  "fzf ships fzf_fd_opts snippet" = fzf.home.file ? ".config/fish/conf.d/fzf.fish";
  "fzf sets FZF_TMUX" = fzf.home.sessionVariables.FZF_TMUX == "1";
  "fzf sets FZF_TMUX_HEIGHT" = fzf.home.sessionVariables.FZF_TMUX_HEIGHT == "80";
  "fzf sets FZF_ALT_C_COMMAND" = fzf.home.sessionVariables.FZF_ALT_C_COMMAND == "fd -t d . $HOME";
  "fzf sets FZF_CTRL_T_COMMAND" = fzf.home.sessionVariables.FZF_CTRL_T_COMMAND == "fd . $HOME/source/ --exclude vendor --exclude node_modules";
  "fzf sets FZF_CTRL_T_OPTS" = fzf.home.sessionVariables.FZF_CTRL_T_OPTS == "--preview 'bat --color always {} 2>/dev/null or cat -n {} || eza --color always -l --git --git-ignore {} 2>/dev/null || tree -C {} 2>/dev/null | head -200' --select-1 --exit-0";
  "fzf sets FZF_CTRL_R_OPTS" = fzf.home.sessionVariables.FZF_CTRL_R_OPTS == "--sort --exact --preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'";
  "fzf sets FZF_DEFAULT_OPTS" = fzf.home.sessionVariables.FZF_DEFAULT_OPTS == "--color=16,fg+:-1:reverse,bg+:-1,hl+:-1:reverse";
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

  # ast-grep, duckdb, git-absorb, jujutsu, mergiraf.
  "ast-grep installs its package" = installs (mk [T."ast-grep"]) "ast-grep";
  "duckdb installs its package" = installs (mk [T.duckdb]) "duckdb";
  "agent-tools includes ast-grep and duckdb" = installs agentTools "ast-grep" && installs agentTools "duckdb";
  "git-absorb installs its package and sets maxStack" =
    installs (mk [T.git T."git-absorb"]) "git-absorb"
    && ((mk [T.git T."git-absorb"]).programs.git.settings.absorb.maxStack or null) == 50;
  "jujutsu installs its package" = installs (mk [T.jujutsu]) "jujutsu";
  "git alone has no mergiraf driver or attributes" =
    !(git.programs.git.settings.merge ? mergiraf) && git.programs.git.attributes == [];
  "git with mergiraf sets merge driver and attributes" = let
    c = mk [T.git T.mergiraf];
  in
    installs c "mergiraf"
    && (c.programs.git.settings.merge.mergiraf.driver or null) == "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L"
    && builtins.elem "*.nix merge=mergiraf" c.programs.git.attributes
    && builtins.elem "*.go merge=mergiraf" c.programs.git.attributes;
  "git-tools includes git-absorb, jujutsu and mergiraf" =
    installs gitTools "git-absorb" && installs gitTools "jujutsu" && installs gitTools "mergiraf";

  # skillshare: owns mutable state, so Home Manager installs the binary and
  # reconciles through the CLI but never writes its config.yaml.
  "skillshare installs its package" = installs skillshare "skillshare";
  "skillshare with package null installs nothing" = !(installs (mk [T.skillshare {tools.skillshare.package = null;}]) "skillshare");
  "skillshare installs rtk for its hook" = installs skillshare "rtk";
  "skillshare with rtkPackage null installs no rtk" = !(installs (mk [T.skillshare {tools.skillshare.rtkPackage = null;}]) "rtk");
  "skillshare installs codebase-memory-mcp for its MCP server" = installs skillshare "codebase-memory-mcp";
  "skillshare with codebaseMemoryPackage null drops the server" =
    !(installs (mk [T.skillshare {tools.skillshare.codebaseMemoryPackage = null;}]) "codebase-memory-mcp")
    && !(builtins.elem "codebase-memory-mcp" (ssNames "mcp" (mk [T.skillshare {tools.skillshare.codebaseMemoryPackage = null;}])));
  "disabled skillshare installs nothing and does not reconcile" =
    !(installs skillshareOff "skillshare") && !(skillshareOff.home.activation ? skillshare);
  "skillshare default profiles are claude and pi" =
    ss.profiles
    == {
      claude = {
        agent = "claude";
        configDir = "/home/t/.claude";
      };
      pi = {
        agent = "pi";
        configDir = "/home/t/.pi/agent";
      };
    };
  "skillshare targets antigravity-cli only when that tool is enabled" =
    !(ss.profiles ? antigravity-cli)
    && (mk [T.skillshare T.antigravity-cli]).tools.skillshare.profiles.antigravity-cli.agent == "antigravity-cli";
  "skillshare targets codex only when that tool is enabled" =
    !(ss.profiles ? codex)
    && (mk [T.skillshare T.codex]).tools.skillshare.profiles.codex.agent == "codex";
  "skillshare targets opencode only when that tool is enabled" =
    !(ss.profiles ? opencode)
    && (mk [T.skillshare T.opencode]).tools.skillshare.profiles.opencode.agent == "opencode";
  "skillshare consumer profiles add to the defaults" =
    builtins.attrNames ssExtra.tools.skillshare.profiles == ["claude" "claude-extra" "pi"];
  "skillshare does not own config.yaml" =
    !(builtins.any (lib.hasInfix "skillshare/config.yaml") (builtins.attrNames skillshare.home.file));
  "skillshare reconciles after writeBoundary" =
    builtins.elem "writeBoundary" skillshare.home.activation.skillshare.after
    && lib.hasInfix "reconcile.sh" skillshare.home.activation.skillshare.data;
  "skillshare enables AgentGateway on Darwin" = (mkOn "aarch64-darwin" [T.skillshare]).tools.skillshare.enableAgentgateway;
  "skillshare omits AgentGateway on Linux" = !(mkOn "x86_64-linux" [T.skillshare]).tools.skillshare.enableAgentgateway;
  "skillshare reconciles after packages are installed" = builtins.elem "installPackages" skillshare.home.activation.skillshare.after;
  "skillshare reconciles after files are linked" = builtins.elem "linkGeneration" skillshare.home.activation.skillshare.after;
  "agent-tools group brings skillshare" = agentTools.tools.skillshare.enable && installs agentTools "skillshare";

  # Bundles, from the discovery fixture.
  "skillshare plugins are exactly the approved bundles" =
    ssNames "plugins" skillshare == lib.sort (a: b: a < b) (["beads" "ponytail" "superpowers"] ++ ssClaudeOnly ++ jskswamyBundles);
  "skillshare fixture covers every bundle" = builtins.all (n: ssCompat ? ${n}) (ssNames "plugins" skillshare);
  "skillshare binds each bundle to every compatible target" = builtins.all (e:
    ssTargets e == builtins.filter (t: builtins.elem ss.profiles.${t}.agent ssCompat.${e.name}.agents) ssAll)
  ssRes.plugins;
  "skillshare binds Ponytail and Superpowers everywhere" = ssTargets (ssEntry "plugins" "ponytail") == ssAll && ssTargets (ssEntry "plugins" "superpowers") == ssAll;
  "skillshare binds portable bundles to Codex and Antigravity CLI" =
    builtins.all (n: ssCliTargets n == ["antigravity-cli" "claude" "codex" "pi"]) ["ponytail" "superpowers"];
  "skillshare binds Beads to Codex and Antigravity CLI but not Pi" =
    ssCliTargets "beads" == ["antigravity-cli" "claude" "codex"];
  "skillshare binds Claude-compatible bundles to Antigravity CLI" =
    builtins.all (n: ssCliTargets n == ["antigravity-cli" "claude"]) (["context7" "mattpocock-skills"] ++ jskswamyBundles)
    && ssCliTargets "gopls-lsp" == ["claude"];
  "skillshare excludes bundled standalone skills on Antigravity CLI" =
    builtins.elem "beads" (ssCli.tools.skillshare.resources.excludes.antigravity-cli or [])
    && builtins.elem "commit-action" (ssCli.tools.skillshare.resources.excludes.antigravity-cli or [])
    && !(ssCli.tools.skillshare.resources.excludes ? codex && builtins.elem "commit-action" ssCli.tools.skillshare.resources.excludes.codex);
  "skillshare keeps Beads and jskswamy bundles off Pi" =
    builtins.all (n: ssTargets (ssEntry "plugins" n) == ssClaude) (["beads"] ++ jskswamyBundles);
  "skillshare keeps Context7, gopls and Matt Pocock bundles on Claude only" =
    builtins.all (n: ssTargets (ssEntry "plugins" n) == ssClaude && ssTargets (ssExtraEntry "plugins" n) == ["claude" "claude-extra"]) ssClaudeOnly;
  "skillshare installs Context7 and gopls from the official marketplace" =
    builtins.all (n: (ssEntry "plugins" n).args == ["plugin" "add" "anthropics/claude-plugins-official" "--plugin" n "--target" "claude" "--json"]) ["context7" "gopls-lsp"];
  "skillshare installs Matt Pocock skills from their repository" =
    (ssEntry "plugins" "mattpocock-skills").args == ["plugin" "add" "mattpocock/skills" "--plugin" "mattpocock-skills" "--target" "claude" "--json"];
  "skillshare binds plugins to declared profiles only" =
    builtins.all (c: builtins.all (e: builtins.all (t: c.tools.skillshare.profiles ? ${t}) (ssTargets e)) c.tools.skillshare.resources.plugins) [skillshare ssExtra];
  "skillshare leaves Context7 MCP to its plugin" = !(builtins.elem "context7" (ssNames "mcp" skillshare));
  "skillshare installs jskswamy/skills bundles from that repo" =
    builtins.all (n: lib.take 3 (ssEntry "plugins" n).args == ["plugin" "add" "jskswamy/skills"] && builtins.elem n (ssEntry "plugins" n).args) jskswamyBundles;
  "skillshare selects stable Superpowers only" =
    lib.take 3 (ssEntry "plugins" "superpowers").args
    == ["plugin" "add" "obra/superpowers"]
    && !(builtins.any (a: lib.hasInfix "superpowers-dev" a || lib.hasInfix "superpowers-marketplace" a || a == "--source-ref") ssArgs);
  "skillshare installs standalone skills for uncovered targets" =
    ssNames "skills" skillshare
    == ["beads" "release" "setup-matt-pocock-skills"]
    && builtins.elem "jskswamy/skills/skills" (ssEntry "skills" "release").args
    && builtins.elem "skill" (ssEntry "skills" "release").args;
  "skillshare installs exactly the Matt Pocock bundle's skills standalone" =
    lib.take 2 ssMatt.args
    == ["install" "mattpocock/skills"]
    && lib.sort (a: b: a < b) (lib.splitString "," (lib.last ssMatt.args)) == lib.sort (a: b: a < b) (ssBundled "mattpocock-skills")
    && builtins.elem "setup-matt-pocock-skills" (ssBundled "mattpocock-skills");
  "skillshare skips standalone Beads when every target has the plugin" =
    ssNames "skills" (mk [T.skillshare {tools.skillshare.profiles = lib.mkForce {inherit (ss.profiles) claude;};}]) == ["release"];
  "skillshare excludes bundled skills on Claude targets" = builtins.all (t:
    ssExcludes t == lib.sort (a: b: a < b) (lib.concatMap ssBundled (["beads" "mattpocock-skills"] ++ jskswamyBundles)))
  ssClaude;
  "skillshare leaves uncovered skills visible to Claude" = builtins.all (t: !(builtins.elem "release" (ssExcludes t))) ssClaude;
  "skillshare excludes nothing on Pi" = ssExcludes "pi" == [];
  "skillshare omits OpenSpec and RTK skills" =
    !(builtins.any (a: lib.hasInfix "openspec" (lib.toLower a) || lib.hasInfix "rtk-ai" a) ssArgs)
    && !(builtins.any (e: lib.hasInfix "rtk" e.name) (ssRes.skills ++ ssRes.plugins));
  "skillshare represents RTK only as its rewrite hook" =
    ssNames "hooks" skillshare
    == ["rtk"]
    && lib.sort (a: b: a < b) (builtins.attrNames ssRtk.bindings) == ssClaude
    && builtins.all (b:
      b.events.PreToolUse
      == [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "rtk hook claude";
            }
          ];
        }
      ]) (builtins.attrValues ssRtk.bindings);
  "skillshare creates consumer account targets under their own config dir" =
    ssExtraTarget.args
    == ["target" "add" "claude-extra" "--agent" "claude" "--config-dir" "/home/t/.claude-extra"]
    && ssExtraTarget.dirs == ["/home/t/.claude-extra"];
  "skillshare binds Claude bundles to consumer account profiles" =
    ssTargets (ssExtraEntry "plugins" "beads")
    == ["claude" "claude-extra"]
    && ssExtra.tools.skillshare.resources.excludes.claude-extra == ssRes.excludes.claude;
  "skillshare declares only the default targets" = map (t: t.name) ssDecl.targets == ["claude" "pi"];
  "skillshare declares the agents plugin sync needs" = ssDecl.agents == ["claude" "pi"];

  # MCP routing.
  "skillshare default MCP servers" = ssNames "mcp" skillshare == ["agentgateway" "chrome-devtools" "codebase-memory-mcp" "time"];
  "skillshare routes portable MCP to every profile" = builtins.all (n: ssTargets (ssEntry "mcp" n) == ssAll) ["time" "chrome-devtools" "agentgateway" "codebase-memory-mcp"];
  "skillshare routes a consumer MCP server to its listed profiles only" =
    ssExtraEntry "mcp" "extra"
    == {
      name = "extra";
      args = ["mcp" "add" "extra" "--target" "claude-extra" "--url" "https://mcp.example.invalid/mcp"];
    };
  "skillshare routes default MCP to consumer profiles too" =
    ssTargets (ssExtraEntry "mcp" "time") == ["claude" "claude-extra" "pi"];
  "skillshare rejects MCP routed to an unknown profile" =
    builtins.elem "tools.skillshare.mcpServers lists unknown profiles: extra -> nope" ssBadMcp;
  "skillshare time runs from the stable profile path" =
    lib.takeEnd 2 (ssEntry "mcp" "time").args == ["--" "${skillshare.home.profileDirectory}/bin/mcp-server-time"];
  "skillshare installs the time server" = installs skillshare "mcp-server-time";
  "skillshare installs no time server when its package is null" = !(installs ssNoTime "mcp-server-time");
  "skillshare registers no time MCP when its package is null" = !(builtins.elem "time" (ssNames "mcp" ssNoTime));
  "skillshare registers a consumer time MCP when its package is null" =
    lib.takeEnd 2 (lib.findFirst (e: e.name == "time") {args = [];} ssOwnTime.tools.skillshare.resources.mcp).args
    == ["--" "/opt/time/bin/mcp-server-time"]
    && !(installs ssOwnTime "mcp-server-time");
  "skillshare pins Chrome DevTools MCP" =
    lib.takeEnd 6 (ssEntry "mcp" "chrome-devtools").args == ["--" "npx" "-y" "chrome-devtools-mcp@1.11.0" "--browser-url" "http://localhost:9222"];
  "skillshare points at the AgentGateway endpoint" =
    lib.takeEnd 2 (ssEntry "mcp" "agentgateway").args == ["--url" "http://127.0.0.1:3050/mcp"];
  "skillshare omits AgentGateway when disabled" = !(builtins.elem "agentgateway" (ssNames "mcp" ssNoGateway));
  "skillshare omits AgentGateway on Linux by default" = !(builtins.elem "agentgateway" (ssNames "mcp" (mkOn "x86_64-linux" [T.skillshare])));
}
