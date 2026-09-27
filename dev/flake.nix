{
  description = "Development shell for nix-modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
    ...
  }: let
    inherit (nixpkgs) lib;

    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = lib.genAttrs systems;
  in {
    checks = forAllSystems (system: {
      pre-commit-check = git-hooks.lib.${system}.run {
        src = ../.;
        hooks = {
          alejandra.enable = true;
          gitleaks = {
            enable = true;
            entry = "gitleaks protect --staged --redact --verbose";
            language = "system";
            pass_filenames = false;
            always_run = true;
            stages = ["pre-commit" "pre-push"];
          };
          check-added-large-files.enable = true;
          check-merge-conflicts.enable = true;
          end-of-file-fixer.enable = true;
          trim-trailing-whitespace.enable = true;
          shellcheck.enable = true;
          shfmt.enable = true;
          stylua.enable = true;
          yamllint.enable = true;
          markdownlint = {
            enable = true;
            # Generated documentation uses inline anchors and table formatting
            # that are intentionally outside the handwritten markdown rules.
            excludes = ["^docs/tools\\.md$"];
            settings.configuration = {
              MD013 = {
                line_length = 80;
                tables = false;
                code_blocks = false;
              };
              MD033.allowed_elements = ["a" "br"];
            };
          };
          prettier = {
            enable = true;
            # Generated documentation is excluded for the same reason as
            # markdownlint above.
            excludes = ["^docs/tools\\.md$"];
            types_or = ["json" "yaml" "markdown"];
          };
        };
      };
    });

    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      pre-commit-check = self.checks.${system}.pre-commit-check;
    in {
      default = pkgs.mkShell {
        inherit (pre-commit-check) shellHook;
        nativeBuildInputs = pre-commit-check.enabledPackages ++ [pkgs.git];
      };
    });
  };
}
