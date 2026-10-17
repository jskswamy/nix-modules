{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.fresh;
  json = pkgs.formats.json {};
in {
  imports = [../../_common];

  options.tools.fresh = {
    enable = mkToolEnable lib "fresh";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.fresh-editor;
      description = "Fresh editor package, or null to configure an existing installation.";
    };

    languageServers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        gopls
        pyright
        rust-analyzer
        typescript-language-server
        yaml-language-server
        taplo
        marksman
        nil
        vscode-langservers-extracted
        bash-language-server
      ];
      description = "Language servers for Go, Python, Rust, JS/TS, YAML, TOML, Markdown, Nix, JSON, HTML/CSS and Bash.";
    };

    settings = lib.mkOption {
      type = json.type;
      default = {};
      description = "Fresh config.json settings. Project configuration can override these defaults.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package ++ cfg.languageServers;

    tools.fresh.settings = {
      # ANSI colors follow the terminal's palette, including live light/dark changes.
      theme = lib.mkDefault "terminal";
      check_for_updates = lib.mkDefault false;
      lsp_enabled = lib.mkDefault true;
      plugins.vi_mode = {
        enabled = lib.mkDefault true;
        settings.autoStart = lib.mkDefault true;
      };
      lsp =
        lib.genAttrs [
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
        ] (_: {
          enabled = lib.mkDefault true;
          auto_start = lib.mkDefault true;
        })
        // {
          python = {
            command = lib.mkDefault "pyright-langserver";
            args = lib.mkDefault ["--stdio"];
            enabled = lib.mkDefault true;
            auto_start = lib.mkDefault true;
          };
        };
    };

    home.file.".config/fresh/config.json".text = builtins.toJSON cfg.settings;
  };
}
